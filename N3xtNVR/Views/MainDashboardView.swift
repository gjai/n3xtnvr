import SwiftUI

struct MainDashboardView: View {
    @EnvironmentObject private var session: AppSession

    var body: some View {
        NavigationSplitView {
            List(1 ... session.settings.channelCount, id: \.self) { ch in
                Button {
                    session.selectedChannel = ch
                } label: {
                    HStack {
                        Image(systemName: "video.fill")
                            .foregroundStyle(session.selectedChannel == ch ? Color.accentColor : .secondary)
                        Text(session.cameraTitle(for: ch))
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .tag(ch)
            }
            .navigationTitle("Caméras")
            .frame(minWidth: 200)
        } detail: {
            VStack(alignment: .leading, spacing: 0) {
                toolbar
                Divider()
                CameraGridView()
                    .environmentObject(session)
                Divider()
                ptzBar
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Surveillance")
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu("Grille") {
                    Button("2 × 2") { session.updateGridSize(2) }
                    Button("4 × 4") { session.updateGridSize(4) }
                }
            }
            ToolbarItem(placement: .automatic) {
                Button("Déconnexion") {
                    session.disconnect()
                }
            }
        }
    }

    private var toolbar: some View {
        HStack {
            Text("Voie PTZ : \(session.cameraTitle(for: session.selectedChannel))")
                .font(.headline)
            Spacer()
            if let msg = session.statusMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var ptzBar: some View {
        HStack(spacing: 12) {
            Text("PTZ")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            ptzGroup

            Spacer()

            Text("Appliqué au canal sélectionné (DVRIP)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(.bar)
    }

    private var ptzGroup: some View {
        HStack(spacing: 8) {
            ForEach([PTZDirection.left, .up, .down, .right, .zoomIn, .zoomOut]) { dir in
                Button {
                    Task { await session.ptz(dir) }
                } label: {
                    Image(systemName: dir.symbol)
                        .frame(width: 28, height: 28)
                }
                .help(dir.rawValue)
                .buttonStyle(.bordered)
            }
        }
    }
}
