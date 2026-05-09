import AppKit
import SwiftUI

struct RTSPPlayerCell: View {
    let url: URL?
    let label: String

    @State private var phase: NVRStreamPhase = .connecting

    var body: some View {
        ZStack {
            if let url {
                MacAVPlayerView(url: url, phase: $phase)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                Rectangle()
                    .fill(Color(nsColor: .underPageBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay {
                        Text("URL RTSP invalide")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
            }

            if url != nil {
                switch phase {
                case .connecting:
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.black.opacity(0.35))
                        .overlay {
                            ProgressView()
                                .controlSize(.regular)
                                .tint(.white)
                        }
                case .failed(let message):
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.black.opacity(0.72))
                        .overlay {
                            Text(message)
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.white)
                                .padding(12)
                        }
                case .playing:
                    EmptyView()
                }
            }
        }
        .overlay(alignment: .bottomLeading) {
            Text(label)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
                .padding(10)
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .onChange(of: url?.absoluteString ?? "") { _, _ in
            phase = .connecting
        }
    }
}
