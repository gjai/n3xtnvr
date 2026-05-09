import AVFoundation
import AVKit
import Foundation
import SwiftUI

/// Remplace les libellés système peu clairs (« URL non gérée », etc.) par une aide actionnable.
private func rtspFriendlyMessage(_ error: Error?) -> String {
    guard let error else { return "Erreur de lecture inconnue." }
    let ns = error as NSError
    if ns.domain == NSURLErrorDomain {
        switch ns.code {
        case NSURLErrorUnsupportedURL:
            return """
            L’URL n’est pas prise en charge par le lecteur intégré (AVPlayer). Sur macOS, certains RTSP (transport, codec, chemin) ne passent pas. Essayez : sous-flux (subtype 1), autre modèle d’URL pour votre NVR, ou test du même lien avec ffplay (voir README).
            """
        case NSURLErrorCannotConnectToHost, NSURLErrorCannotFindHost, NSURLErrorTimedOut:
            return "Connexion RTSP impossible (hôte, port 554 ou pare-feu). Vérifiez l’IP, le port RTSP et le réseau local."
        default:
            break
        }
    }
    let d = error.localizedDescription
    let lower = d.lowercased()
    if (lower.contains("non gér") && lower.contains("url"))
        || lower.contains("unsupported")
        || lower.contains("not supported")
        || lower.contains("cannot be supported") {
        return """
        Ce flux n’est pas géré par AVPlayer sur macOS (limitation fréquente avec le RTSP). Solutions possibles : sous-flux H.264 (subtype 1), autre chemin RTSP dans « modèle URL », ou validation du flux avec ffplay.
        """
    }
    return d
}

/// Phase affichée dans la cellule (connexion, lecture, échec explicite).
enum NVRStreamPhase: Equatable {
    case connecting
    case playing
    case failed(String)
}

/// Lecteur RTSP via AVKit. Les flux « live » nécessitent souvent `automaticallyWaitsToMinimizeStalling = false`.
struct MacAVPlayerView: NSViewRepresentable {
    let url: URL
    @Binding var phase: NVRStreamPhase

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> AVPlayerView {
        context.coordinator.phaseBinding = $phase

        let view = AVPlayerView()
        view.controlsStyle = .none
        view.showsFullScreenToggleButton = false
        view.showsSharingServiceButton = false
        view.videoGravity = .resizeAspect

        let player = AVPlayer()
        player.automaticallyWaitsToMinimizeStalling = false
        player.isMuted = true
        player.actionAtItemEnd = .none

        context.coordinator.player = player
        view.player = player
        context.coordinator.load(url: url)
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        context.coordinator.phaseBinding = $phase
        nsView.player = context.coordinator.player
        if let p = context.coordinator.player,
           let item = p.currentItem,
           let a = item.asset as? AVURLAsset,
           a.url == url {
            return
        }
        context.coordinator.load(url: url)
    }

    static func dismantleNSView(_ nsView: AVPlayerView, coordinator: Coordinator) {
        coordinator.teardown()
        nsView.player = nil
    }

    final class Coordinator {
        var phaseBinding: Binding<NVRStreamPhase>?
        fileprivate var player: AVPlayer?
        private var statusObservation: NSKeyValueObservation?
        private var failedObserver: NSObjectProtocol?
        private var timeoutWorkItem: DispatchWorkItem?

        func load(url: URL) {
            stopObserving()
            phaseBinding?.wrappedValue = .connecting

            guard let player else { return }
            let asset = AVURLAsset(
                url: url,
                options: [AVURLAssetPreferPreciseDurationAndTimingKey: false]
            )
            let item = AVPlayerItem(asset: asset)
            item.preferredForwardBufferDuration = 0.5
            item.canUseNetworkResourcesForLiveStreamingWhilePaused = true

            player.replaceCurrentItem(with: item)
            observe(item: item)
            player.play()

            let work = DispatchWorkItem { [weak self] in
                guard let self, let b = self.phaseBinding else { return }
                if case .playing = b.wrappedValue { return }
                if case .failed = b.wrappedValue { return }
                b.wrappedValue = .failed(
                    "Pas de vidéo après 18 s. Essayez le sous-flux (subtype 1), vérifiez identifiants et mot de passe RTSP, ou changez le modèle d’URL selon le constructeur."
                )
            }
            timeoutWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 18, execute: work)
        }

        private func observe(item: AVPlayerItem) {
            statusObservation = item.observe(\.status, options: [.new]) { [weak self] it, _ in
                guard let self, let b = self.phaseBinding else { return }
                DispatchQueue.main.async {
                    switch it.status {
                    case .readyToPlay:
                        b.wrappedValue = .playing
                        self.cancelTimeout()
                    case .failed:
                        b.wrappedValue = .failed(rtspFriendlyMessage(it.error))
                        self.cancelTimeout()
                    case .unknown:
                        break
                    @unknown default:
                        break
                    }
                }
            }

            failedObserver = NotificationCenter.default.addObserver(
                forName: AVPlayerItem.failedToPlayToEndTimeNotification,
                object: item,
                queue: .main
            ) { [weak self] note in
                guard let self, let b = self.phaseBinding else { return }
                let err = note.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
                b.wrappedValue = .failed(rtspFriendlyMessage(err))
                self.cancelTimeout()
            }
        }

        private func stopObserving() {
            statusObservation?.invalidate()
            statusObservation = nil
            if let failedObserver {
                NotificationCenter.default.removeObserver(failedObserver)
                self.failedObserver = nil
            }
            cancelTimeout()
        }

        private func cancelTimeout() {
            timeoutWorkItem?.cancel()
            timeoutWorkItem = nil
        }

        func teardown() {
            stopObserving()
            player?.pause()
            player?.replaceCurrentItem(with: nil)
            player = nil
        }
    }
}
