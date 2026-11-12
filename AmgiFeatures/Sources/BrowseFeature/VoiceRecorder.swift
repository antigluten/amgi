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
        case endedEarly
    }

    /// Field index currently being recorded into, if any.
    private(set) var recordingFieldIndex: Int?
    private(set) var recordingStartedAt: Date?
    private(set) var playingURL: URL?
    var failure: Failure?
    @ObservationIgnored var onEndedEarly: ((fieldIndex: Int, url: URL)) -> Void = { _ in }

    @ObservationIgnored private var recorder: AVAudioRecorder?
    @ObservationIgnored private var player: AVAudioPlayer?
    @ObservationIgnored private var playbackEndTask: Task<Void, Never>?
    @ObservationIgnored private var interruptionTask: Task<Void, Never>?
    @ObservationIgnored private var recorderDelegate: RecorderDelegate?

    private static let maxDuration: TimeInterval = 600

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
            .appendingPathComponent("amgi-voice-\(UUID().uuidString).m4a")
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
            let delegate = RecorderDelegate { [weak self, weak recorder] in
                guard let self, let recorder, self.recorder === recorder else { return }
                self.endEarly()
            }
            recorder.delegate = delegate
            guard recorder.record(forDuration: Self.maxDuration) else { throw CocoaError(.fileWriteUnknown) }
            self.recorder = recorder
            recorderDelegate = delegate
            interruptionTask = Task { [weak self] in
                for await note in NotificationCenter.default.notifications(named: AVAudioSession.interruptionNotification) {
                    let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
                    if raw == AVAudioSession.InterruptionType.began.rawValue { self?.endEarly() }
                }
            }
            recordingFieldIndex = fieldIndex
            recordingStartedAt = .now
        } catch {
            Self.log.error("Could not start recording: \(error)")
            failure = .couldNotStart
            try? FileManager.default.removeItem(at: url)
            deactivateSession()
        }
    }

    /// Stops the current recording and returns the clip, or nil if it was too
    /// short to be intentional (an accidental tap).
    func stop() -> (fieldIndex: Int, url: URL)? {
        guard let recorder, let fieldIndex = recordingFieldIndex else { return nil }
        // currentTime reads 0 once the system has stopped the recorder (duration cap, encode error).
        let duration = recordingStartedAt.map { Date.now.timeIntervalSince($0) } ?? 0
        recorder.stop()
        self.recorder = nil
        recorderDelegate = nil
        interruptionTask?.cancel()
        interruptionTask = nil
        recordingFieldIndex = nil
        recordingStartedAt = nil
        deactivateSession()

        guard duration >= 0.3 else {
            try? FileManager.default.removeItem(at: recorder.url)
            return nil
        }
        return (fieldIndex, recorder.url)
    }

    private func endEarly() {
        guard let clip = stop() else { return }
        failure = .endedEarly
        onEndedEarly(clip)
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

private final class RecorderDelegate: NSObject, AVAudioRecorderDelegate, @unchecked Sendable {
    private let onEnd: @MainActor () -> Void
    init(onEnd: @escaping @MainActor () -> Void) { self.onEnd = onEnd }

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor [onEnd] in onEnd() }
    }

    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: (any Error)?) {
        Task { @MainActor [onEnd] in onEnd() }
    }
}
#endif
