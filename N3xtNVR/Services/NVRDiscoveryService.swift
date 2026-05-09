import Darwin
import Foundation

/// Découverte d’équipements DVRIP sur le LAN (UDP multicast / broadcast), alignée sur go2rtc.
/// Port 34569, requête d’enregistrement réseau ; réponses JSON avec en-tête 20 octets (protocole NETSurveillance).
enum NVRDiscoveryService {
    enum DiscoveryError: LocalizedError {
        case socketCreationFailed
        case bindFailed
        case sendFailed

        var errorDescription: String? {
            switch self {
            case .socketCreationFailed:
                return "Impossible de créer la socket UDP (vérifiez les permissions réseau)."
            case .bindFailed:
                return "Port UDP 34569 indisponible (autre app ou pare-feu)."
            case .sendFailed:
                return "Échec d’envoi du paquet de découverte."
            }
        }
    }

    struct DiscoveredNVR: Identifiable, Hashable {
        let id: String
        let ipv4: String
        let name: String
        let tcpPort: Int
        let serialNumber: String?
        /// Nombre de voies annoncé par l’équipement (si présent dans la réponse).
        let channelCount: Int?

        var summary: String {
            "\(name) — \(ipv4):\(tcpPort)"
        }
    }

    /// Paquet magique go2rtc / clients XMeye ICSee (20 octets).
    private static let discoveryPacket = Data([
        0xff, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0xfa, 0x05, 0x00, 0x00, 0x00, 0x00
    ])

    private static let discoveryUDPPort: UInt16 = 34569
    private static let multicastGroup = "239.255.255.250"

    /// Lance une recherche sur le réseau local (quelques secondes).
    static func discover(listenDuration: TimeInterval = 4.2) async throws -> [DiscoveredNVR] {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let list = try scanSync(listenDuration: listenDuration)
                    continuation.resume(returning: list)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func scanSync(listenDuration: TimeInterval) throws -> [DiscoveredNVR] {
        let sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard sock >= 0 else { throw DiscoveryError.socketCreationFailed }
        defer { close(sock) }

        var yes: Int32 = 1
        setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))
        setsockopt(sock, SOL_SOCKET, SO_BROADCAST, &yes, socklen_t(MemoryLayout<Int32>.size))

        var bindAddr = sockaddr_in()
        bindAddr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        bindAddr.sin_family = sa_family_t(AF_INET)
        bindAddr.sin_port = discoveryUDPPort.bigEndian
        bindAddr.sin_addr.s_addr = inet_addr("0.0.0.0")

        let bindRes = withUnsafePointer(to: &bindAddr) { ptr -> Int32 in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindRes == 0 else { throw DiscoveryError.bindFailed }

        // Réception des annonces multicast (go2rtc écoute 239.255.255.250:34569).
        var mreq = ip_mreq()
        mreq.imr_multiaddr.s_addr = inet_addr(multicastGroup)
        mreq.imr_interface.s_addr = inet_addr("0.0.0.0")
        _ = withUnsafePointer(to: &mreq) { p -> Int32 in
            p.withMemoryRebound(to: Int8.self, capacity: MemoryLayout<ip_mreq>.size) { ptr in
                setsockopt(sock, IPPROTO_IP, IP_ADD_MEMBERSHIP, ptr, socklen_t(MemoryLayout<ip_mreq>.size))
            }
        }

        let broadcastTargets: [String] = {
            var s = Set<String>()
            s.insert("255.255.255.255")
            s.insert(multicastGroup)
            for b in ipv4BroadcastAddresses() {
                s.insert(b)
            }
            return Array(s)
        }()

        for _ in 0 ..< 4 {
            usleep(100_000)
            for bcast in broadcastTargets {
                var dest = sockaddr_in()
                dest.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
                dest.sin_family = sa_family_t(AF_INET)
                dest.sin_port = discoveryUDPPort.bigEndian
                dest.sin_addr.s_addr = inet_addr(bcast)

                let sent = discoveryPacket.withUnsafeBytes { raw -> ssize_t in
                    let base = raw.bindMemory(to: UInt8.self).baseAddress!
                    return withUnsafePointer(to: &dest) { dptr in
                        dptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { saptr in
                            sendto(
                                sock,
                                base,
                                discoveryPacket.count,
                                0,
                                saptr,
                                socklen_t(MemoryLayout<sockaddr_in>.size)
                            )
                        }
                    }
                }
                guard sent == discoveryPacket.count else { throw DiscoveryError.sendFailed }
            }
        }

        var byKey: [String: DiscoveredNVR] = [:]
        var buffer = [UInt8](repeating: 0, count: 65_536)
        let deadline = Date().addingTimeInterval(listenDuration)

        while Date() < deadline {
            var pfd = pollfd()
            pfd.fd = sock
            pfd.events = Int16(POLLIN)
            pfd.revents = 0
            let remainingMs = max(0, Int((deadline.timeIntervalSinceNow * 1000.0).rounded()))
            let waitMs = min(remainingMs, 200)
            let pr = poll(&pfd, 1, Int32(waitMs))
            if pr < 0 { break }
            if pr == 0 { continue }
            if pfd.revents & Int16(POLLIN) == 0 { continue }

            var src = sockaddr_in()
            var srcLen = socklen_t(MemoryLayout<sockaddr_in>.size)
            let n = buffer.withUnsafeMutableBufferPointer { bufPtr -> ssize_t in
                guard let base = bufPtr.baseAddress else { return -1 }
                return withUnsafeMutablePointer(to: &src) { sptr in
                    sptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { saptr in
                        recvfrom(sock, base, bufPtr.count, 0, saptr, &srcLen)
                    }
                }
            }
            guard n > 20 else { continue }

            let data = Data(buffer[0 ..< Int(n)])
            let senderStr = String(cString: inet_ntoa(src.sin_addr))
            guard let parsed = parseDiscoveryPacket(data, packetSourceIPv4: senderStr) else { continue }
            let key = "\(parsed.ipv4):\(parsed.tcpPort)"
            if byKey[key] == nil {
                byKey[key] = parsed
            }
        }

        return Array(byKey.values).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private static func parseDiscoveryPacket(_ data: Data, packetSourceIPv4: String) -> DiscoveredNVR? {
        guard data.count > 21 else { return nil }

        // Réponses observées : JSON après 20 octets ; dernier octet \0 ou \n (go2rtc : n-1).
        var candidates: [Data] = []
        let trimmedEnd = data.last == 0 ? data.count - 1 : data.count
        if trimmedEnd > 20 {
            candidates.append(data.subdata(in: 20 ..< trimmedEnd))
        }
        if data.count > 21 {
            let slice = data.subdata(in: 20 ..< (data.count - 1))
            if !candidates.contains(where: { $0 == slice }) {
                candidates.append(slice)
            }
        }
        var payload = data.subdata(in: 20 ..< data.count)
        while let last = payload.last, last == 0 || last == 10 || last == 13 {
            payload = payload.dropLast()
        }
        if !payload.isEmpty, candidates.firstIndex(of: payload) == nil {
            candidates.insert(payload, at: 0)
        }

        for raw in candidates {
            if let d = decodeNetCommon(from: raw, packetSourceIPv4: packetSourceIPv4) {
                return d
            }
        }
        return nil
    }

    private static func decodeNetCommon(from payload: Data, packetSourceIPv4: String) -> DiscoveredNVR? {
        guard !payload.isEmpty else { return nil }

        struct NetCommonDTO: Decodable {
            let HostIP: String?
            let HostName: String?
            let TCPPort: Int?
            let SN: String?
            let ChannelNum: Int?
        }

        struct Envelope: Decodable {
            let Ret: Int?
            let netCommon: NetCommonDTO?
            enum CodingKeys: String, CodingKey {
                case Ret
                case netCommon = "NetWork.NetCommon"
            }
        }

        let decoder = JSONDecoder()
        var nc: NetCommonDTO?

        if let env = try? decoder.decode(Envelope.self, from: payload) {
            nc = env.netCommon
        }

        if nc == nil, let obj = try? JSONSerialization.jsonObject(with: payload) as? [String: Any] {
            if let inner = obj["NetWork.NetCommon"] as? [String: Any] {
                let d = try? JSONSerialization.data(withJSONObject: inner)
                if let d, let n = try? decoder.decode(NetCommonDTO.self, from: d) {
                    nc = n
                }
            }
            if nc == nil, let name = obj["HostName"] as? String {
                let ipStr = obj["HostIP"] as? String
                let tcp = obj["TCPPort"] as? Int
                nc = NetCommonDTO(
                    HostIP: ipStr,
                    HostName: name,
                    TCPPort: tcp,
                    SN: obj["SN"] as? String,
                    ChannelNum: obj["ChannelNum"] as? Int
                )
            }
        }

        guard let net = nc else { return nil }

        let tcpPort = net.TCPPort.flatMap { $0 > 0 ? $0 : nil } ?? 34_567
        let name = (net.HostName?.isEmpty == false ? net.HostName! : "NVR")

        let ipFromJson = net.HostIP.flatMap { decodeHexHostIP($0) }
        let fallbackIP: String? = packetSourceIPv4.isEmpty ? nil : packetSourceIPv4
        guard let ipv4 = ipFromJson ?? fallbackIP else { return nil }

        let id = "\(ipv4)-\(tcpPort)-\(net.SN ?? "")"
        return DiscoveredNVR(
            id: id,
            ipv4: ipv4,
            name: name,
            tcpPort: tcpPort,
            serialNumber: net.SN,
            channelCount: net.ChannelNum
        )
    }

    /// Adresses de diffusion IPv4 par interface (complète 255.255.255.255).
    private static func ipv4BroadcastAddresses() -> [String] {
        var list: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&list) == 0, let first = list else { return [] }
        defer { freeifaddrs(list) }

        var out: [String] = []
        var seen = Set<UInt32>()
        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let p = ptr {
            defer { ptr = p.pointee.ifa_next }

            if let name = p.pointee.ifa_name {
                let ifName = String(cString: name)
                if ifName.hasPrefix("lo") || ifName == "utun0" { continue }
            }

            guard let addrPtr = p.pointee.ifa_addr,
                  addrPtr.pointee.sa_family == UInt8(AF_INET),
                  let maskPtr = p.pointee.ifa_netmask
            else { continue }

            let sin = addrPtr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
            let mask = maskPtr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
            let ip = sin.sin_addr.s_addr
            let m = mask.sin_addr.s_addr

            let copy = sin.sin_addr
            let ipStr = String(cString: inet_ntoa(copy))
            if ipStr.hasPrefix("127.") || ip == 0 { continue }

            let bc = ip | (~m)
            if seen.insert(bc).inserted {
                let baddr = in_addr(s_addr: bc)
                let bStr = String(cString: inet_ntoa(baddr))
                out.append(bStr)
            }
        }
        return out
    }

    /// Chaîne `0xXXXXXXXX` ou hex 8 caractères → IPv4 (ordre d’octets go2rtc / little-endian sur le fil).
    private static func decodeHexHostIP(_ hex: String) -> String? {
        var s = hex
        if s.hasPrefix("0x") || s.hasPrefix("0X") { s.removeFirst(2) }
        s = s.trimmingCharacters(in: .whitespaces)
        guard s.count == 8, s.count % 2 == 0 else { return nil }
        var bytes = [UInt8]()
        var i = s.startIndex
        while i < s.endIndex {
            let j = s.index(i, offsetBy: 2, limitedBy: s.endIndex) ?? s.endIndex
            guard let b = UInt8(s[i..<j], radix: 16) else { return nil }
            bytes.append(b)
            i = j
        }
        guard bytes.count == 4 else { return nil }
        return "\(Int(bytes[3])).\(Int(bytes[2])).\(Int(bytes[1])).\(Int(bytes[0]))"
    }
}

/// Résolution DNS « best effort » pour un ID cloud / série (hôtes connus dans l’écosystème XM ; pas de P2P propriétaire).
enum CloudIDResolver {
    /// Retourne le premier nom d’hôte joignable par DNS parmi des candidats dérivés du serial.
    static func resolve(_ raw: String) async -> String? {
        await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                let id = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                guard !id.isEmpty else {
                    cont.resume(returning: nil)
                    return
                }
                if id.contains(".") {
                    cont.resume(returning: resolveHostIfReachable(id) ? id : nil)
                    return
                }

                let candidates: [String] = [
                    "\(id).devices.cloudlinks.cn",
                    "\(id).cloudlinks.cn",
                    "\(id).cloudlinks.net",
                    "\(id).xmeye.net",
                    "\(id).xmcs.xiongmai.net",
                ]

                for h in candidates {
                    if resolveHostIfReachable(h) {
                        cont.resume(returning: h)
                        return
                    }
                }
                cont.resume(returning: nil)
            }
        }
    }

    private static func resolveHostIfReachable(_ host: String) -> Bool {
        var hints = addrinfo(
            ai_flags: AI_ADDRCONFIG,
            ai_family: AF_INET,
            ai_socktype: SOCK_STREAM,
            ai_protocol: IPPROTO_TCP,
            ai_addrlen: 0,
            ai_canonname: nil,
            ai_addr: nil,
            ai_next: nil
        )
        var res: UnsafeMutablePointer<addrinfo>?
        let ret = getaddrinfo(host, "34567", &hints, &res)
        defer {
            if res != nil { freeaddrinfo(res) }
        }
        return ret == 0 && res != nil
    }
}
