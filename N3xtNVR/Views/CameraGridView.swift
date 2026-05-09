import SwiftUI

struct CameraGridView: View {
    @EnvironmentObject private var session: AppSession

    private var columns: [GridItem] {
        let n = session.gridSpan
        return Array(repeating: GridItem(.flexible(), spacing: 8), count: n)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(session.visibleChannels, id: \.self) { ch in
                cell(for: ch)
            }
        }
        .padding(8)
    }

    @ViewBuilder
    private func cell(for channel: Int) -> some View {
        let url = session.streamSettings.rtspURL(forChannel: channel)
        let selected = session.selectedChannel == channel

        RTSPPlayerCell(url: url, label: session.cameraTitle(for: channel))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(selected ? Color.accentColor : Color.clear, lineWidth: 3)
            )
            .onTapGesture {
                session.selectedChannel = channel
            }
            .id("ch-\(channel)-\(session.settings.rtspSubtype)")
    }
}
