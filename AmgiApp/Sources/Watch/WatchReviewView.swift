import AVFoundation
import AnkiBackend
import AnkiKit
import Dependencies
import SwiftUI

struct WatchReviewView: View {
    let deckId: Int64
    let onDismiss: () -> Void
    @State private var session: ReviewSession
    @State private var audioPlayer = AVQueuePlayer()
    @Environment(\.dismiss) private var dismiss
    init(deckId: Int64, onDismiss: @escaping () -> Void) {
        self.deckId = deckId
        self.onDismiss = onDismiss
        self._session = State(initialValue: ReviewSession(deckId: deckId))
    }
    var body: some View {
        VStack {
            if session.isFinished {
                finishedView
            } else {
                VStack(spacing: 0) {
                    ScrollView {
                        Text(session.showAnswer ? session.backHTML.stripped : session.frontHTML.stripped)
                            .font(.title3)
                            .multilineTextAlignment(.center)
                    }
                    if session.showAnswer {
                        HStack(spacing: 0) {
                            ratingButton(.again, color: .red)
                            ratingButton(.good, color: .green)
                        }
                    } else {
                        reviewButton("Show Answer", color: .blue) { session.revealAnswer() }
                    }
                }
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .background(Color.black)
        ._statusBarHidden()
        .toolbar(.hidden, for: .navigationBar)
        .ignoresSafeArea(edges: .top)
        .onTapGesture { playAudio(from: session.showAnswer ? session.backHTML : session.frontHTML) }
        .onTapGesture(count: 2) { dismiss() }
        .task {
            do {
                try await AVAudioSession.sharedInstance().setCategory(
                    .playback,
                    mode: .default,
                    policy: .longFormAudio
                )
                try await AVAudioSession.sharedInstance().activate(options: [])
            } catch {
                // Audio may fail silently on watchOS if session setup errors.
            }
            await session.start()
        }
        .onChange(of: session.frontHTML) { _, new in playAudio(from: new) }
        .onChange(of: session.showAnswer) { _, show in if show { playAudio(from: session.backHTML) } }
    }
    private var finishedView: some View {
        VStack {
            Spacer()
            Image(systemName: "checkmark.circle.fill").font(.largeTitle).foregroundStyle(.green)
            Text("Finished!").font(.headline)
            Text("\(session.sessionStats.reviewed) cards").font(.caption).foregroundStyle(.secondary)
            Spacer()
            Button("Done") { onDismiss() }.buttonStyle(.borderedProminent)
        }.padding()
    }
    private func reviewButton(_ title: String, color: Color, font: Font = .headline, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(font).frame(maxWidth: .infinity)
        }
        .padding(10).buttonStyle(.plain).frame(maxWidth: .infinity).background(color)
    }
    private func ratingButton(_ rating: Rating, color: Color) -> some View {
        reviewButton(session.nextIntervals[rating] ?? "", color: color, font: .caption) {
            session.answer(rating: rating)
        }
    }
    private func playAudio(from html: String) {
        @Dependency(\.ankiBackend) var backend
        guard let mediaDir = backend.currentMediaFolderPath,
            let regex = try? NSRegularExpression(pattern: #"(?i)\[sound:(.+?)\]"#)
        else { return }
        let items = regex.matches(in: html, range: NSRange(html.startIndex..., in: html)).compactMap { match -> AVPlayerItem? in
            guard let range = Range(match.range(at: 1), in: html) else { return nil }
            return AVPlayerItem(url: URL(fileURLWithPath: mediaDir).appendingPathComponent(String(html[range])))
        }
        audioPlayer.removeAllItems()
        items.forEach { if audioPlayer.canInsert($0, after: nil) { audioPlayer.insert($0, after: nil) } }
        audioPlayer.play()
    }
}
extension String {
    fileprivate var stripped: String {
        self.replacingOccurrences(of: "(?s)<style.*?>.*?</style>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\[sound:[^\]]+\]"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\n\s*\n"#, with: "\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
