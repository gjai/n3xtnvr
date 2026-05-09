import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var session: AppSession
    @State private var isBusy = false
    @State private var showNetworkDiscovery = false

    private var canConnect: Bool {
        let h = session.settings.host.trimmingCharacters(in: .whitespacesAndNewlines)
        let c = session.settings.cloudID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !h.isEmpty || !c.isEmpty
    }

    var body: some View {
        VStack(spacing: 24) {
            Text("N3xtNVR")
                .font(.largeTitle.weight(.semibold))
            Text("NETSurveillance · DVRIP (TCP \(session.settings.controlPort)) · RTSP local")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Form {
                Section {
                    HStack(alignment: .firstTextBaseline) {
                        TextField("IP, DDNS ou hostname", text: $session.settings.host)
                        Button("Rechercher…") {
                            showNetworkDiscovery = true
                        }
                        .help("Découverte DVRIP sur le réseau local (UDP 34569)")
                    }
                    TextField("Cloud ID (XMeye / série)", text: Binding(
                        get: { session.settings.cloudID ?? "" },
                        set: { session.settings.cloudID = $0.isEmpty ? nil : $0 }
                    ))
                    .help("Si renseigné, résolution DNS vers un hôte cloud (best effort) ; l’IP ci-dessus est ignorée pour la connexion.")
                    TextField("Port TCP DVRIP", value: $session.settings.controlPort, format: .number)
                        .help("34567 par défaut pour NETSurveillance")
                    TextField("Utilisateur", text: $session.settings.username)
                    SecureField("Mot de passe", text: $session.settings.password)
                } header: {
                    Text("Connexion NVR")
                } footer: {
                    Text(
                        "Recherche locale : multicast + diffusion par sous-réseau (UDP 34569). Si le Cloud ID est renseigné, il remplace l’adresse pour la connexion. Résolution DNS vers des hôtes connus (cloudlinks, etc.) — le P2P propriétaire XMeye n’est pas implémenté ; l’IP LAN ou un DDNS restent les plus fiables."
                    )
                    .font(.caption)
                }

                Section {
                    TextField("Port RTSP", value: $session.settings.rtspPort, format: .number)
                        .help("Souvent 554")
                    Picker("Sous-flux", selection: $session.settings.rtspSubtype) {
                        Text("Principal (H.265/H.264)").tag(0)
                        Text("Sous-flux").tag(1)
                    }
                    Stepper("Nombre de voies : \(session.settings.channelCount)", value: $session.settings.channelCount, in: 1 ... 32)
                    TextField("Modèle URL RTSP", text: $session.settings.rtspURLTemplate, axis: .vertical)
                        .lineLimit(3 ... 6)
                } header: {
                    Text("Flux vidéo RTSP")
                } footer: {
                    Text(
                        "Placeholders : {user} {pass} {host} {port} {channel} {subtype} — modèle type Xiongmai / cam/realmonitor."
                    )
                    .font(.caption)
                }
            }
            .formStyle(.grouped)
            .frame(maxWidth: 520)

            if let err = session.lastError {
                Text(err)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .frame(maxWidth: 420)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 16) {
                Button("Enregistrer le profil") {
                    session.saveSettings()
                }
                .keyboardShortcut("s", modifiers: [.command])

                Button(action: {
                    Task {
                        isBusy = true
                        session.saveSettings()
                        await session.connect()
                        isBusy = false
                    }
                }) {
                    if isBusy {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.horizontal, 8)
                    } else {
                        Text("Connexion")
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isBusy || !canConnect)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showNetworkDiscovery) {
            NVRDiscoveryView(settings: $session.settings)
        }
    }
}
