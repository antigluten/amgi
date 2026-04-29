import SwiftUI
import AmgiTheme
import AnkiKit

struct ReviewView: View {
    let deckId: Int64
    let onDismiss: () -> Void

    @Environment(\.palette) private var palette
    @State private var session: ReviewSession

    init(deckId: Int64, onDismiss: @escaping () -> Void) {
        self.deckId = deckId
        self.onDismiss = onDismiss
        self._session = State(initialValue: ReviewSession(deckId: deckId))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    DeckCountsView(counts: session.remainingCounts)
                    Spacer()
                    Text("\(session.sessionStats.reviewed) reviewed")
                        .amgiFont(.caption)
                        .foregroundStyle(palette.textSecondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                if session.isFinished {
                    finishedView
                } else {
                    cardView
                }
            }
            .background(palette.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { onDismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        session.undo()
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .disabled(!session.canUndo)
                }
            }
        }
        .task {
            session.start()
        }
        .onDisappear {
            Task { await writeWidgetSnapshot() }
        }
    }

    @ViewBuilder
    private var cardView: some View {
        VStack(spacing: 0) {
            if session.showAnswer {
                CardWebView(html: session.backHTML)
            } else {
                CardWebView(html: session.frontHTML)
            }

            Spacer()

            if session.showAnswer {
                answerButtons
            } else {
                Button {
                    session.revealAnswer()
                } label: {
                    Text("Show Answer")
                        .amgiFont(.bodyEmphasis)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .padding()
            }
        }
    }

    private var answerButtons: some View {
        HStack(spacing: 8) {
            ratingButton(.again, color: .red)
            ratingButton(.hard, color: .orange)
            ratingButton(.good, color: .green)
            ratingButton(.easy, color: .blue)
        }
        .padding()
    }

    private func ratingButton(_ rating: Rating, color: Color) -> some View {
        Button {
            session.answer(rating: rating)
        } label: {
            VStack(spacing: 4) {
                Text(session.nextIntervals[rating] ?? "")
                    .font(.caption2)
                Text(ratingLabel(rating))
                    .font(.subheadline.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(.bordered)
        .tint(color)
    }

    private func ratingLabel(_ rating: Rating) -> String {
        switch rating {
        case .again: "Again"
        case .hard: "Hard"
        case .good: "Good"
        case .easy: "Easy"
        }
    }

    private func formatInterval(_ days: Int) -> String {
        if days == 0 { return "<1d" }
        if days < 30 { return "\(days)d" }
        if days < 365 { return "\(days / 30)mo" }
        return String(format: "%.1fy", Double(days) / 365.0)
    }

    private var finishedView: some View {
        VStack(spacing: AmgiSpacing.lg) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
            Text("Congratulations!")
                .amgiFont(.sectionHeading)
                .foregroundStyle(palette.textPrimary)
            Text("You've reviewed \(session.sessionStats.reviewed) cards")
                .amgiFont(.body)
                .foregroundStyle(palette.textSecondary)
            if session.sessionStats.reviewed > 0 {
                Text("Accuracy: \(Int(session.sessionStats.accuracy * 100))%")
                    .amgiFont(.body)
                    .foregroundStyle(palette.textSecondary)
            }
            Spacer()
            Button("Done") { onDismiss() }
                .buttonStyle(AmgiPrimaryButtonStyle())
                .padding()
        }
    }
}
