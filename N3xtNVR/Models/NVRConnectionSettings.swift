import Foundation

/// Paramètres de connexion au NVR (DVRIP / NETSurveillance).
struct NVRConnectionSettings: Codable, Equatable {
    /// Adresse IP locale, DDNS ou hostname joignable (utilisé si `cloudID` est vide).
    var host: String
    /// Identifiant cloud / série XMeye : résolution DNS « best effort » vers un hôte (P2P propriétaire non implémenté).
    var cloudID: String?
    var controlPort: Int
    var username: String
    var password: String

    /// Port RTSP du NVR (souvent 554).
    var rtspPort: Int
    /// Sous-flux : 0 = principal (H.265/H.264), 1 = sous-flux.
    var rtspSubtype: Int
    /// Modèle d’URL ; placeholders : {user} {pass} {host} {port} {channel} {subtype}
    var rtspURLTemplate: String
    /// Nombre de voies (16 pour NBD80S16S).
    var channelCount: Int

    static let defaultRTSPTemplate =
        "rtsp://{user}:{pass}@{host}:{port}/cam/realmonitor?channel={channel}&subtype={subtype}"

    static var `default`: NVRConnectionSettings {
        NVRConnectionSettings(
            host: "192.168.1.100",
            cloudID: nil,
            controlPort: 34_567,
            username: "admin",
            password: "",
            rtspPort: 554,
            rtspSubtype: 0,
            rtspURLTemplate: NVRConnectionSettings.defaultRTSPTemplate,
            channelCount: 16
        )
    }

    enum CodingKeys: String, CodingKey {
        case host, cloudID, controlPort, username, password, rtspPort, rtspSubtype
        case rtspURLTemplate, channelCount
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        host = try c.decode(String.self, forKey: .host)
        cloudID = try c.decodeIfPresent(String.self, forKey: .cloudID)
        controlPort = try c.decode(Int.self, forKey: .controlPort)
        username = try c.decode(String.self, forKey: .username)
        password = try c.decode(String.self, forKey: .password)
        rtspPort = try c.decode(Int.self, forKey: .rtspPort)
        rtspSubtype = try c.decode(Int.self, forKey: .rtspSubtype)
        rtspURLTemplate = try c.decode(String.self, forKey: .rtspURLTemplate)
        channelCount = try c.decode(Int.self, forKey: .channelCount)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(host, forKey: .host)
        try c.encodeIfPresent(cloudID, forKey: .cloudID)
        try c.encode(controlPort, forKey: .controlPort)
        try c.encode(username, forKey: .username)
        try c.encode(password, forKey: .password)
        try c.encode(rtspPort, forKey: .rtspPort)
        try c.encode(rtspSubtype, forKey: .rtspSubtype)
        try c.encode(rtspURLTemplate, forKey: .rtspURLTemplate)
        try c.encode(channelCount, forKey: .channelCount)
    }

    init(
        host: String,
        cloudID: String?,
        controlPort: Int,
        username: String,
        password: String,
        rtspPort: Int,
        rtspSubtype: Int,
        rtspURLTemplate: String,
        channelCount: Int
    ) {
        self.host = host
        self.cloudID = cloudID
        self.controlPort = controlPort
        self.username = username
        self.password = password
        self.rtspPort = rtspPort
        self.rtspSubtype = rtspSubtype
        self.rtspURLTemplate = rtspURLTemplate
        self.channelCount = channelCount
    }

    func rtspURL(forChannel channel: Int) -> URL? {
        let encUser = NVRConnectionSettings.percentEncodeUserInfo(username)
        let encPass = NVRConnectionSettings.percentEncodeUserInfo(password)
        let hostTrim = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let tpl = rtspURLTemplate
            .replacingOccurrences(of: "{user}", with: encUser)
            .replacingOccurrences(of: "{pass}", with: encPass)
            .replacingOccurrences(of: "{host}", with: hostTrim)
            .replacingOccurrences(of: "{port}", with: String(rtspPort))
            .replacingOccurrences(of: "{channel}", with: String(channel))
            .replacingOccurrences(of: "{subtype}", with: String(rtspSubtype))
        return URL(string: tpl)
    }

    private static func percentEncodeUserInfo(_ s: String) -> String {
        let unreserved: Set<UInt8> = Set(
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~".utf8
        )
        return s.utf8.map { b -> String in
            if unreserved.contains(b) {
                let c = UnicodeScalar(b)
                return String(Character(c))
            }
            return String(format: "%%%02X", b)
        }.joined()
    }
}
