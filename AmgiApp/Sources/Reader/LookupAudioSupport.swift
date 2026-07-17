import AVFoundation
import Foundation

enum LookupAudioPlaybackMode: String, CaseIterable, Identifiable, Sendable {
    case interrupt
    case duck
    case mix

    var id: String { rawValue }

    var label: String {
        switch self {
        case .interrupt: return "Interrupt other audio"
        case .duck: return "Duck other audio"
        case .mix: return "Mix with other audio"
        }
    }
}

enum LookupAudioDefaults {
    static let defaultTemplate = "https://hoshi-reader.manhhaoo-do.workers.dev/?term={term}&reading={reading}"

    static func resolvedTemplate(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? defaultTemplate : trimmed
    }

    static func resolvedPlaybackMode(_ raw: String) -> LookupAudioPlaybackMode {
        LookupAudioPlaybackMode(rawValue: raw) ?? .interrupt
    }
}

/// Single shared AVPlayer-backed actor. One playback at a time — starting a
/// new entry's audio cancels the previous one, matching DreamAfar's UX
/// where the play button is a "play this term now" affordance not a
/// queue. Audio session lifecycle (activate/deactivate) is owned here so
/// callers don't have to coordinate it.
actor LookupAudioPlayer {
    static let shared = LookupAudioPlayer()

    private var player: AVPlayer?
    private var playToEndObserver: NSObjectProtocol?
    private var failedToEndObserver: NSObjectProtocol?

    func play(url: URL, mode: LookupAudioPlaybackMode) {
        stopPlayback(deactivateSession: false)

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: categoryOptions(for: mode))
            try session.setActive(true, options: [])
        } catch {
            return
        }

        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        self.player = player

        playToEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: nil
        ) { [weak self] _ in
            Task { await self?.stop() }
        }

        failedToEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: item,
            queue: nil
        ) { [weak self] _ in
            Task { await self?.stop() }
        }

        player.play()
    }

    func stop() {
        stopPlayback(deactivateSession: true)
    }

    private func stopPlayback(deactivateSession: Bool) {
        player?.pause()
        player = nil

        if let playToEndObserver {
            NotificationCenter.default.removeObserver(playToEndObserver)
            self.playToEndObserver = nil
        }
        if let failedToEndObserver {
            NotificationCenter.default.removeObserver(failedToEndObserver)
            self.failedToEndObserver = nil
        }

        if deactivateSession {
            try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        }
    }

    private func categoryOptions(for mode: LookupAudioPlaybackMode) -> AVAudioSession.CategoryOptions {
        switch mode {
        case .interrupt: return []
        case .duck: return [.mixWithOthers, .duckOthers]
        case .mix: return [.mixWithOthers]
        }
    }
}

/// Resolves an audio URL for a term/reading by templating the user's
/// configured source endpoint and decoding the Yomichan-style
/// `audioSourceList` response. First successful response wins.
enum LookupAudioResolver {
    private struct AudioSourceResponse: Decodable {
        struct Item: Decodable {
            var name: String
            var url: String
        }
        var type: String
        var audioSources: [Item]
    }

    static func resolve(
        term: String,
        reading: String?,
        template: String
    ) async -> URL? {
        let resolvedTemplate = LookupAudioDefaults.resolvedTemplate(template)
        let target = resolvedTemplate
            .replacingOccurrences(
                of: "{term}",
                with: term.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? term
            )
            .replacingOccurrences(
                of: "{reading}",
                with: (reading ?? term).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? (reading ?? term)
            )

        guard let url = URL(string: target) else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(AudioSourceResponse.self, from: data)
            guard response.type == "audioSourceList",
                  let first = response.audioSources.first,
                  let resolved = URL(string: first.url) else {
                return nil
            }
            return resolved
        } catch {
            return nil
        }
    }
}
