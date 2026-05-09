import SwiftUI

/// Feuille de sélection d’un NVR détecté via DVRIP UDP (port 34569).
struct NVRDiscoveryView: View {
    @Binding var settings: NVRConnectionSettings
    @Environment(\.dismiss) private var dismiss

    @State private var devices: [NVRDiscoveryService.DiscoveredNVR] = []
    @State private var isScanning = true
    @State private var scanError: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isScanning {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text("Recherche sur le réseau local (UDP 34569, ~4 s)…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                } else if let scanError {
                    Text(scanError)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                }

                if devices.isEmpty, !isScanning, scanError == nil {
                    ContentUnavailableView(
                        "Aucun NVR détecté",
                        systemImage: "wifi.exclamationmark",
                        description: Text(
                            "Vérifiez le Wi‑Fi / Ethernet, le pare-feu macOS, et que l’enregistreur répond au protocole DVRIP (XM / NETSurveillance)."
                        )
                    )
                } else {
                    List(devices) { item in
                        Button {
                            apply(item)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.name)
                                    .font(.headline)
                                Text("\(item.ipv4) · TCP \(item.tcpPort)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if let sn = item.serialNumber, !sn.isEmpty {
                                    Text("S/N \(sn)")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                                if let ch = item.channelCount, ch > 0 {
                                    Text("\(ch) voie(s)")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text(
                    "La recherche utilise le port UDP 34569 (annonces sur le LAN). Le contrôle DVRIP se fait en TCP 34567. Ce n’est pas le port 34659."
                )
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .padding(.bottom, 6)
            }
            .navigationTitle("Recherche NVR")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Actualiser") {
                        Task { await runScan() }
                    }
                    .disabled(isScanning)
                }
            }
        }
        .frame(minWidth: 420, minHeight: 360)
        .task {
            await runScan()
        }
    }

    private func apply(_ item: NVRDiscoveryService.DiscoveredNVR) {
        settings.host = item.ipv4
        settings.controlPort = item.tcpPort
        if let c = item.channelCount, c > 0 {
            settings.channelCount = min(max(c, 1), 32)
        }
        dismiss()
    }

    private func runScan() async {
        scanError = nil
        isScanning = true
        devices = []
        do {
            devices = try await NVRDiscoveryService.discover()
        } catch {
            scanError = error.localizedDescription
        }
        isScanning = false
    }
}
