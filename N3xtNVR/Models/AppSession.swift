import Combine
import Foundation

@MainActor
final class AppSession: ObservableObject {
    @Published var settings: NVRConnectionSettings
    @Published var isConnected = false
    @Published var statusMessage: String?
    @Published var lastError: String?

    /// Grille : 2 → 2×2, 4 → 4×4
    @Published var gridSpan: Int = 2
    @Published var selectedChannel: Int = 1
    @Published var visibleChannels: [Int]
    /// Un titre par voie (index 0 = canal 1), rempli après connexion DVRIP si l’équipement répond.
    @Published var channelTitles: [String] = []
    /// Hôte utilisé pour TCP/RTSP après résolution Cloud ID (sinon identique à `settings.host`).
    @Published private(set) var activeStreamHost: String?

    private var dvr: DVRIPClient?
    private var settingsStore: UserDefaults { UserDefaults.standard }
    private let settingsKey = "n3xtnvr.settings"

    init() {
        let loaded: NVRConnectionSettings
        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(NVRConnectionSettings.self, from: data) {
            loaded = decoded
        } else {
            loaded = .default
        }
        settings = loaded
        visibleChannels = Array(1 ... min(4, loaded.channelCount))
    }

    func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            settingsStore.set(data, forKey: settingsKey)
        }
    }

    /// Paramètres effectifs pour les URL RTSP (`host` remplacé par l’hôte résolu si besoin).
    var streamSettings: NVRConnectionSettings {
        var s = settings
        if let h = activeStreamHost, !h.isEmpty {
            s.host = h
        }
        return s
    }

    func connect() async {
        lastError = nil
        channelTitles = []
        activeStreamHost = nil
        var conn = settings
        let trimmedCloud = settings.cloudID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedCloud.isEmpty {
            statusMessage = "Résolution Cloud ID…"
            if let resolved = await CloudIDResolver.resolve(trimmedCloud) {
                conn.host = resolved
                activeStreamHost = resolved
            } else {
                dvr = nil
                isConnected = false
                statusMessage = nil
                lastError =
                    "Impossible de résoudre le Cloud ID en adresse DNS. Utilisez l’IP du LAN, un DDNS, ou vérifiez le réseau / pare-feu."
                return
            }
        }

        statusMessage = "Connexion…"
        dvr?.stop()
        let client = DVRIPClient(settings: conn)
        do {
            try await client.connectAndLogin()
            dvr = client
            if activeStreamHost == nil {
                activeStreamHost = conn.host.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            isConnected = true
            statusMessage = "Chargement des caméras…"
            if let titles = try? await client.fetchChannelTitles(), !titles.isEmpty {
                channelTitles = titles
            } else {
                channelTitles = []
            }
            statusMessage = "Connecté (session DVRIP)"
            visibleChannels = Array(1 ... min(gridSpan * gridSpan, settings.channelCount))
            if selectedChannel > settings.channelCount { selectedChannel = 1 }
        } catch {
            dvr = nil
            isConnected = false
            channelTitles = []
            lastError = error.localizedDescription
            statusMessage = nil
        }
    }

    func disconnect() {
        dvr?.stop()
        dvr = nil
        isConnected = false
        statusMessage = nil
        channelTitles = []
        activeStreamHost = nil
    }

    /// Libellé affiché pour la voie `channel` (1…N).
    func cameraTitle(for channel: Int) -> String {
        let idx = channel - 1
        if idx >= 0, idx < channelTitles.count {
            let t = channelTitles[idx].trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { return t }
        }
        return "Canal \(channel)"
    }

    func ptz(_ command: PTZDirection, step: Int = 5) async {
        guard let dvr else { return }
        do {
            try await dvr.ptz(command: command, channel: selectedChannel - 1, step: step)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func updateGridSize(_ span: Int) {
        gridSpan = span
        let maxCells = span * span
        visibleChannels = Array(1 ... min(maxCells, settings.channelCount))
    }

    func applyChannelCountChange() {
        let maxCells = gridSpan * gridSpan
        visibleChannels = Array(1 ... min(maxCells, settings.channelCount))
        if selectedChannel > settings.channelCount { selectedChannel = max(1, settings.channelCount) }
    }
}
