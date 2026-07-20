import AVFoundation
import Foundation
import Observation

/// Queue player for a native card's `[sound:…]` markers (R11). The WebView
/// path plays audio inside the page; the native path plays the extracted
/// files from the collection media folder here.
@Observable @MainActor
final class NativeCardAudioPlayer {
    private(set) var isPlaying = false

    private var player: AVQueuePlayer?
    private var endObserver: NSObjectProtocol?

    func play(files: [String], mediaFolder: URL?) {
        stop()
        guard let mediaFolder, !files.isEmpty else { return }
        let items = files.map { AVPlayerItem(url: mediaFolder.appendingPathComponent($0)) }
        let player = AVQueuePlayer(items: items)
        self.player = player
        isPlaying = true
        endObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: items.last,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.finish() }
        }
        player.play()
    }

    func stop() {
        player?.pause()
        player?.removeAllItems()
        finish()
    }

    private func finish() {
        player = nil
        isPlaying = false
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
    }
}
