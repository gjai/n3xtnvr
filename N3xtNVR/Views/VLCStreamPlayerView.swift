import AppKit
import SwiftUI
import VLCKit

/// Lecture RTSP via VLCKit (transport TCP implicite : meilleure compatibilité NVR Xiongmai qu’AVPlayer sur macOS).
struct VLCStreamPlayerView: NSViewRepresentable {
    let url: URL
    @Binding var phase: NVRStreamPhase

    func makeCoordinator() -> Coordinator {
        Coordinator(phase: $phase)
    }

    func makeNSView(context: Context) -> NSView {
        let v = NSView(frame: .zero)
        v.wantsLayer = true
        context.coordinator.attach(to: v)
        context.coordinator.play(url: url)
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.playIfNeeded(url: url)
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.stop()
    }

    final class Coordinator: NSObject, VLCMediaPlayerDelegate {
        var phase: Binding<NVRStreamPhase>
        private let player = VLCMediaPlayer()
        private var currentURL: URL?
        private var timeoutWorkItem: DispatchWorkItem?

        init(phase: Binding<NVRStreamPhase>) {
            self.phase = phase
        }

        func attach(to view: NSView) {
            player.drawable = view
            player.delegate = self
        }

        func play(url: URL) {
            playIfNeeded(url: url)
        }

        func playIfNeeded(url: URL) {
            if currentURL == url { return }
            currentURL = url
            cancelTimeout()
            phase.wrappedValue = .connecting

            guard let media = VLCMedia(url: url) else {
                phase.wrappedValue = .failed("URL média VLC invalide.")
                return
            }
            media.addOption(":network-caching=300")
            media.addOption(":rtsp-tcp")
            media.addOption(":live-caching=300")
            player.media = media
            player.play()

            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                if case .playing = self.phase.wrappedValue { return }
                if case .failed = self.phase.wrappedValue { return }
                self.phase.wrappedValue = .failed(
                    "Pas de vidéo après 25 s. Vérifiez identifiants RTSP, port 554, sous-flux (subtype 1), ou le pare-feu."
                )
            }
            timeoutWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 25, execute: work)
        }

        func stop() {
            cancelTimeout()
            player.delegate = nil
            player.stop()
            player.media = nil
            player.drawable = nil
            currentURL = nil
        }

        deinit {
            player.delegate = nil
            player.stop()
        }

        private func cancelTimeout() {
            timeoutWorkItem?.cancel()
            timeoutWorkItem = nil
        }

        /// Signature exacte `VLCMediaPlayerDelegate` : **VLCMediaPlayerState**, pas `Notification`
        /// (sinon VLC passe un entier d’état ; Swift le traitait comme objet → crash `objc_retain(0x2)`).
        func mediaPlayerStateChanged(_ newState: VLCMediaPlayerState) {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                switch newState {
                case .opening, .buffering:
                    self.phase.wrappedValue = .connecting
                case .playing:
                    self.phase.wrappedValue = .playing
                    self.cancelTimeout()
                case .error:
                    self.phase.wrappedValue = .failed(
                        "Erreur VLC / réseau RTSP. Vérifiez le flux (user/pass, port 554, sous-flux)."
                    )
                    self.cancelTimeout()
                default:
                    break
                }
            }
        }
    }
}
