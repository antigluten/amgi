#if canImport(UIKit)
import Foundation
import SwiftUI
import Theme

struct NoteVoiceRecordButton: View {
    @Environment(\.palette) private var palette
    let recorder: VoiceRecorder
    let fieldIndex: Int
    let onRecorded: (URL) -> Void

    private var isRecordingHere: Bool { recorder.recordingFieldIndex == fieldIndex }

    var body: some View {
        Button {
            if isRecordingHere {
                if let clip = recorder.stop() { onRecorded(clip.url) }
            } else {
                Task { await recorder.start(fieldIndex: fieldIndex) }
            }
        } label: {
            if isRecordingHere, let startedAt = recorder.recordingStartedAt {
                HStack(spacing: 6) {
                    Image(systemName: "stop.circle.fill")
                    TimelineView(.periodic(from: startedAt, by: 1)) { context in
                        let seconds = max(0, Int(context.date.timeIntervalSince(startedAt)))
                        Text(String(format: "%d:%02d", seconds / 60, seconds % 60))
                            .monospacedDigit()
                    }
                }
                .foregroundStyle(palette.danger)
            } else {
                Label("Record", systemImage: "mic.fill")
                    .labelStyle(.iconOnly)
                    .foregroundStyle(palette.accent)
            }
        }
        .buttonStyle(.borderless)
        .amgiFont(.body)
        .disabled(recorder.isStarting || (recorder.isRecording && !isRecordingHere))
        .accessibilityLabel(isRecordingHere ? "Stop recording" : "Record voice")
    }
}

struct NoteVoiceClipRow: View {
    @Environment(\.palette) private var palette
    let title: String
    let isPlaying: Bool
    let onPlay: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Button(action: onPlay) {
                Label(title, systemImage: isPlaying ? "stop.circle.fill" : "play.circle.fill")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(palette.accent)
            Spacer()
            Button(role: .destructive, action: onDelete) {
                Label("Delete \(title)", systemImage: "trash")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
        }
        .amgiFont(.caption)
    }
}
#endif
