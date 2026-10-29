//
//  VoiceRecorder.swift
//  BrowseFeature
//

#if canImport(UIKit)
import AVFoundation
import Foundation
import Observation
import OSLog

/// Records short voice clips for note fields and plays them back for preview.
///
/// Clips land in the temporary directory as AAC `.m4a`; nothing touches the
/// collection's media folder until the note is actually added, so a discarded
/// note leaves no orphaned media behind. One recording or playback at a time.
@Observable
@MainActor
final class VoiceRecorder {
    enum Failure: Equatable {
        case permissionDenied
        case couldNotStart
    }

    /// Field index currently being recorded into, if any.
    private(set) var recordingFieldIndex: Int?
    private(set) var recordingStartedAt: Date?
    private(set) var playingURL: URL?
    var failure: Failure?

    @ObservationIgnored private var recorder: AVAudioRecorder?
    @ObservationIgnored private var player: AVAudioPlayer?
    @ObservationIgnored private var playbackEndTask: Task<Void, Never>?

    private var startRequest: UUID?

    var isStarting: Bool { startRequest != nil }

    private static let log = Logger(subsystem: "com.amgiapp.AmgiApp", category: "VoiceRecorder")

    var isRecording: Bool { recordingFieldIndex != nil }

    /// Starts recording for `fieldIndex`. Asks for microphone access the first time.
    func start(fieldIndex: Int) async {
        guard !isRecording, !isStarting else { return }
        let request = UUID()
        startRequest = request
        defer { if startRequest == request { startRequest = nil } }
        stopPlayback()
        failure = nil

        let permitted = await AVAudioApplication.requestRecordPermission()
        guard startRequest == request, !Task.isCancelled else { return }
        guard permitted else {
            failure = .permissionDenied
            return
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("amgi-voice-\(UUID().uuidString.prefix(8)).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try session.setActive(true)
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            guard recorder.record() else { throw CocoaError(.fileWriteUnknown) }
            self.recorder = recorder
            recordingFieldIndex = fieldIndex
            recordingStartedAt = .now
        } catch {
            Self.log.error("Could not start recording: \(error)")
            failure = .couldNotStart
            deactivateSession()
        }
    }

    /// Stops the current recording and returns the clip, or nil if it was too
    /// short to be intentional (an accidental tap).
    func stop() -> (fieldIndex: Int, url: URL)? {
        guard let recorder, let fieldIndex = recordingFieldIndex else { return nil }
        let duration = recorder.currentTime
        recorder.stop()
        self.recorder = nil
        recordingFieldIndex = nil
        recordingStartedAt = nil
        deactivateSession()

        guard duration >= 0.3 else {
            try? FileManager.default.removeItem(at: recorder.url)
            return nil
        }
        return (fieldIndex, recorder.url)
    }

    /// Abandons an in-flight recording without keeping it.
    func cancel() {
        startRequest = nil
        if let url = stop()?.url {
            try? FileManager.default.removeItem(at: url)
        }
        stopPlayback()
    }

    func togglePlayback(_ url: URL) {
        if playingURL == url {
            stopPlayback()
            return
        }
        stopPlayback()
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            let player = try AVAudioPlayer(contentsOf: url)
            guard player.play() else {
                deactivateSession()
                return
            }
            self.player = player
            playingURL = url
            let duration = player.duration
            playbackEndTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(duration + 0.1))
                guard !Task.isCancelled else { return }
                self?.stopPlayback()
            }
        } catch {
            Self.log.error("Could not play clip: \(error)")
            deactivateSession()
        }
    }

    func stopPlayback() {
        playbackEndTask?.cancel()
        playbackEndTask = nil
        player?.stop()
        player = nil
        playingURL = nil
        if !isRecording { deactivateSession() }
    }

    private func deactivateSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
#endif
