import AVFoundation
import AnkiBackend
import AnkiClients
import AnkiKit
import Dependencies
import Foundation
import SwiftUI

struct WatchReviewView: View {
    let deckId: Int64
    let onDismiss: () -> Void
    @State private var session: ReviewSession
    @State private var audioPlayer: AVPlayer?
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
                cardContent
            }
        }
        .background(Color.amgiBackground)
        ._statusBarHidden()  // hide clock
        .toolbar(.hidden, for: .navigationBar)  // hide close button
        .ignoresSafeArea(edges: .top)
        .task {
            session.start()
        }
        .onChange(of: session.frontHTML) { _, new in
            playAudio(from: new)
        }
        .onChange(of: session.showAnswer) { _, show in
            if show {
                playAudio(from: session.backHTML)
            }
        }
        .onTapGesture(count: 2) {
            dismiss()
        }
    }
    private var cardContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack {
                    if session.showAnswer {
                        Text(stripHTML(session.backHTML))
                            .font(.title3)
                            .multilineTextAlignment(.center)
                    } else {
                        Text(stripHTML(session.frontHTML))
                            .font(.title3)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            if session.showAnswer {
                HStack(spacing: 0) {
                    ratingButton(.again, color: .red)
                    ratingButton(.good, color: .green)
                }
            } else {
                reviewButton(title: "Show Answer", color: .blue) {
                    session.revealAnswer()
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private func reviewButton(title: String, color: Color, font: Font = .headline, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(font)
                .frame(maxWidth: .infinity)
        }
        .padding(10)
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .background(color)
    }

    private func ratingButton(_ rating: Rating, color: Color) -> some View {
        reviewButton(
            title: session.nextIntervals[rating] ?? "",
            color: color,
            font: .caption
        ) {
            session.answer(rating: rating)
        }
    }
    private var finishedView: some View {
        VStack {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.largeTitle)
                .foregroundStyle(.green)
            Text("Finished!")
                .font(.headline)
            Text("\(session.sessionStats.reviewed) cards")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Done") { onDismiss() }
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    private func stripHTML(_ html: String) -> String {
        // Remove style blocks and their content
        let withoutStyle = html.replacingOccurrences(of: "(?s)<style.*?>.*?</style>", with: "", options: .regularExpression)
        // Strip other tags and sound markers
        let stripped = withoutStyle.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\[sound:[^\]]+\]"#, with: "", options: .regularExpression)
        return stripped.replacingOccurrences(of: #"\n\s*\n"#, with: "\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private func playAudio(from html: String) {
        let pattern = #"(?i)\[sound:(.+?)\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html))
        else { return }
        let filename = String(html[Range(match.range(at: 1), in: html)!])
        @Dependency(\.ankiBackend) var backend
        guard let mediaDir = backend.currentMediaFolderPath else { return }
        let fileURL = URL(fileURLWithPath: mediaDir).appendingPathComponent(filename)
        let item = AVPlayerItem(url: fileURL)
        if audioPlayer == nil {
            audioPlayer = AVPlayer(playerItem: item)
        } else {
            audioPlayer?.replaceCurrentItem(with: item)
        }
        audioPlayer?.play()
    }
}
