import CryptoKit
import Foundation
import Network

enum DVRIPError: LocalizedError {
    case notConnected
    case shortRead
    case invalidHeader
    case loginFailed(Int)
    case jsonDecode
    case commandFailed(Int)

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Connexion TCP indisponible."
        case .shortRead:
            return "Trame réseau incomplète."
        case .invalidHeader:
            return "En-tête DVRIP invalide."
        case .loginFailed(let code):
            return "Échec login DVRIP (code \(code))."
        case .jsonDecode:
            return "Réponse JSON illisible."
        case .commandFailed(let code):
            return "Commande refusée (code \(code))."
        }
    }
}

/// Client DVRIP (NETSurveillance / XMeye) sur TCP — aligné sur `python-dvr` / OpenIPC.
final class DVRIPClient: @unchecked Sendable {
    /// File logique DVRIP (login, timers).
    private let queue = DispatchQueue(label: "com.n3xtnvr.dvrip")
    /// File NWConnection — distincte pour éviter le deadlock avec les sémaphores de `syncConnect` / send/receive.
    private let networkQueue = DispatchQueue(label: "com.n3xtnvr.nw")
    private var connection: NWConnection?
    private var packetSequence: UInt32 = 0
    private var sessionId: UInt32 = 0
    private var aliveInterval: TimeInterval = 20
    private var keepAliveTimer: DispatchSourceTimer?

    private let settings: NVRConnectionSettings

    init(settings: NVRConnectionSettings) {
        self.settings = settings
    }

    func stop() {
        queue.async { [weak self] in
            self?.keepAliveTimer?.cancel()
            self?.keepAliveTimer = nil
            self?.connection?.cancel()
            self?.connection = nil
        }
    }

    func connectAndLogin() async throws {
        let hashPass = Self.sofiaHash(settings.password)
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            queue.async {
                do {
                    try self.syncConnect()
                    try self.syncLogin(passwordHash: hashPass)
                    self.scheduleKeepAlive()
                    cont.resume()
                } catch {
                    self.connection?.cancel()
                    self.connection = nil
                    cont.resume(throwing: error)
                }
            }
        }
    }

    func ptz(command: PTZDirection, channel: Int, step: Int) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            queue.async {
                do {
                    try self.syncPTZ(command: command, channel: channel, step: step)
                    cont.resume()
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }
    }

    /// Titres des voies (DVRIP **1048**, équivalent `get_channel_titles` dans python-dvr).
    func fetchChannelTitles() async throws -> [String] {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[String], Error>) in
            queue.async {
                do {
                    let json = try self.syncSend(msgId: 1048, body: [
                        "Name": "ChannelTitle",
                        "SessionID": String(format: "0x%08X", self.sessionId),
                    ])
                    cont.resume(returning: Self.parseChannelTitles(from: json))
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }
    }

    private static func parseChannelTitles(from json: [String: Any]) -> [String] {
        guard let ret = json["Ret"] as? Int, ret == 100 else { return [] }
        return normalizedTitles(json["ChannelTitle"])
    }

    private static func normalizedTitles(_ value: Any?) -> [String] {
        guard let value else { return [] }
        if let a = value as? [String] { return a }
        if let a = value as? [Any] {
            return a.compactMap { $0 as? String }
        }
        if let d = value as? [String: Any] {
            let numericKeys = d.keys.compactMap { Int($0) }.sorted()
            if !numericKeys.isEmpty {
                return numericKeys.compactMap { d[String($0)] as? String }
            }
            return d.values.compactMap { $0 as? String }
        }
        return []
    }

    // MARK: - Sofia / login

    private static func sofiaHash(_ password: String) -> String {
        let digest = Array(Insecure.MD5.hash(data: Data(password.utf8)))
        let chars = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz")
        var out = ""
        var i = 0
        while i < 16 {
            let a = Int(digest[i])
            let b = i + 1 < 16 ? Int(digest[i + 1]) : 0
            out.append(chars[(a + b) % 62])
            i += 2
        }
        return out
    }

    private func syncConnect() throws {
        guard let nwPort = NWEndpoint.Port(rawValue: UInt16(clamping: settings.controlPort)) else {
            throw DVRIPError.notConnected
        }
        let host = NWEndpoint.Host(settings.host)
        let conn = NWConnection(host: host, port: nwPort, using: .tcp)
        connection = conn

        let sem = DispatchSemaphore(value: 0)
        var errOut: Error?
        conn.stateUpdateHandler = { state in
            switch state {
            case .ready:
                sem.signal()
            case .failed(let e):
                errOut = e
                sem.signal()
            case .cancelled:
                if errOut == nil { errOut = DVRIPError.notConnected }
                sem.signal()
            default:
                break
            }
        }
        conn.start(queue: networkQueue)
        let timeout = DispatchTime.now() + .seconds(15)
        if sem.wait(timeout: timeout) == .timedOut {
            conn.cancel()
            throw DVRIPError.notConnected
        }
        if let e = errOut { throw e }
    }

    private func syncLogin(passwordHash: String) throws {
        let body: [String: Any] = [
            "EncryptType": "MD5",
            "LoginType": "DVRIP-Web",
            "PassWord": passwordHash,
            "UserName": settings.username,
        ]
        let json = try syncSend(msgId: 1000, body: body)
        guard let ret = json["Ret"] as? Int else {
            throw DVRIPError.jsonDecode
        }
        if ret != 100 {
            throw DVRIPError.loginFailed(ret)
        }
        if let sid = json["SessionID"] as? String {
            sessionId = Self.parseSessionHex(sid)
        }
        if let alive = json["AliveInterval"] as? Int {
            aliveInterval = TimeInterval(max(10, alive))
        }
    }

    private static func parseSessionHex(_ s: String) -> UInt32 {
        let cleaned = s.hasPrefix("0x") || s.hasPrefix("0X") ? String(s.dropFirst(2)) : s
        return UInt32(cleaned, radix: 16) ?? 0
    }

    private func scheduleKeepAlive() {
        keepAliveTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(
            deadline: .now() + aliveInterval,
            repeating: aliveInterval,
            leeway: .seconds(2)
        )
        timer.setEventHandler { [weak self] in
            try? self?.syncKeepAlive()
        }
        timer.resume()
        keepAliveTimer = timer
    }

    private func syncKeepAlive() throws {
        let body: [String: Any] = [
            "Name": "KeepAlive",
            "SessionID": String(format: "0x%08X", sessionId),
        ]
        _ = try syncSend(msgId: 1006, body: body)
    }

    private func syncPTZ(command: PTZDirection, channel: Int, step: Int) throws {
        let param: [String: Any] = [
            "AUX": ["Number": 0, "Status": "On"] as [String: Any],
            "Channel": channel,
            "MenuOpts": "Enter",
            "Pattern": "Start",
            "Preset": -1,
            "Step": step,
            "Tour": 0,
        ]
        let inner: [String: Any] = [
            "Command": command.rawValue,
            "Parameter": param,
        ]
        let body: [String: Any] = [
            "Name": "OPPTZControl",
            "SessionID": String(format: "0x%08X", sessionId),
            "OPPTZControl": inner,
        ]
        let json = try syncSend(msgId: 1400, body: body)
        if let ret = json["Ret"] as? Int, ret != 100 {
            throw DVRIPError.commandFailed(ret)
        }
    }

    // MARK: - Enveloppe DVRIP

    private func syncSend(msgId: UInt16, body: [String: Any]) throws -> [String: Any] {
        guard let conn = connection else { throw DVRIPError.notConnected }
        let dataJson = try jsonDataCompact(body)
        let payloadLen = UInt32(dataJson.count + 2)
        let header = packHeader(
            session: sessionId,
            sequence: packetSequence,
            msgId: msgId,
            dataLength: payloadLen
        )
        var packet = Data()
        packet.append(header)
        packet.append(dataJson)
        packet.append(contentsOf: [0x0a, 0])

        let sem = DispatchSemaphore(value: 0)
        var sendErr: NWError?
        conn.send(content: packet, completion: .contentProcessed { err in
            sendErr = err
            sem.signal()
        })
        sem.wait()
        if let e = sendErr { throw e }

        let hdrData = try receiveExact(conn: conn, count: 20)
        let parsed = try parseHeader(hdrData)
        let bodyData = try receiveExact(conn: conn, count: Int(parsed.dataLength))

        packetSequence &+= 1

        guard bodyData.count >= 2 else { throw DVRIPError.shortRead }
        let jsonPart = bodyData.prefix(bodyData.count - 2)
        guard let obj = try? JSONSerialization.jsonObject(with: Data(jsonPart)) as? [String: Any]
        else {
            throw DVRIPError.jsonDecode
        }
        return obj
    }

    private func receiveExact(conn: NWConnection, count: Int) throws -> Data {
        var buffer = Data()
        while buffer.count < count {
            let need = count - buffer.count
            let chunk = try receiveChunk(conn: conn, max: need)
            guard !chunk.isEmpty else { throw DVRIPError.shortRead }
            buffer.append(chunk)
        }
        return buffer
    }

    private func receiveChunk(conn: NWConnection, max: Int) throws -> Data {
        let sem = DispatchSemaphore(value: 0)
        var out = Data()
        var errOut: NWError?
        conn.receive(minimumIncompleteLength: 1, maximumLength: max) { data, _, isComplete, error in
            if let d = data { out = d }
            errOut = error
            sem.signal()
        }
        sem.wait()
        if let e = errOut { throw e }
        return out
    }

    private func jsonDataCompact(_ body: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: body, options: [])
    }

    private func packHeader(
        session: UInt32,
        sequence: UInt32,
        msgId: UInt16,
        dataLength: UInt32
    ) -> Data {
        var d = Data()
        d.append(0xFF)
        d.append(0x00)
        d.append(contentsOf: [0x00, 0x00])
        d.append(contentsOf: withUnsafeBytes(of: session.littleEndian) { Data($0) })
        d.append(contentsOf: withUnsafeBytes(of: sequence.littleEndian) { Data($0) })
        d.append(contentsOf: [0x00, 0x00])
        d.append(contentsOf: withUnsafeBytes(of: msgId.littleEndian) { Data($0) })
        d.append(contentsOf: withUnsafeBytes(of: dataLength.littleEndian) { Data($0) })
        return d
    }

    private func parseHeader(_ data: Data) throws -> (dataLength: UInt32, msgId: UInt16) {
        guard data.count == 20, data[0] == 0xFF else {
            throw DVRIPError.invalidHeader
        }
        let len = data.subdata(in: 16 ..< 20).withUnsafeBytes { $0.load(as: UInt32.self) }
        let msg = data.subdata(in: 14 ..< 16).withUnsafeBytes { $0.load(as: UInt16.self) }
        return (len.littleEndian, msg.littleEndian)
    }
}

enum PTZDirection: String, CaseIterable, Identifiable {
    case up = "DirectionUp"
    case down = "DirectionDown"
    case left = "DirectionLeft"
    case right = "DirectionRight"
    case zoomIn = "ZoomTile"
    case zoomOut = "ZoomWide"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .up: return "arrow.up"
        case .down: return "arrow.down"
        case .left: return "arrow.left"
        case .right: return "arrow.right"
        case .zoomIn: return "plus.magnifyingglass"
        case .zoomOut: return "minus.magnifyingglass"
        }
    }
}
