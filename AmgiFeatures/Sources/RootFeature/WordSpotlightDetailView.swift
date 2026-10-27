import AppCore
import AppShared
import SwiftUI
import Theme

struct WordSpotlightDetailView: View {
    let link: WordSpotlightLink
    @Environment(\.palette) private var palette
    @State private var state = ViewState.loading
    private let controller = WordSpotlightController.shared

    private enum ViewState {
        case loading
        case loaded(SpotlightWord, AdvanceState)
        case failed(String)
    }

    private enum AdvanceState {
        case idle
        case loading
        case failed(String)

        var isLoading: Bool {
            if case .loading = self { return true }
            return false
        }
    }

    var body: some View {
        content
            .background(palette.background)
            .navigationTitle("Word Spotlight")
            .navigationBarTitleDisplayMode(.inline)
            .task(id: link.url) { await load() }
    }

    @ViewBuilder private var content: some View {
        switch state {
        case .loading:
            ProgressView()
        case .loaded(let word, let advanceState):
            wordContent(word, advanceState: advanceState)
        case .failed(let message):
            ContentUnavailableView("Word unavailable", systemImage: "character.book.closed", description: Text(message))
        }
    }

    private func wordContent(_ word: SpotlightWord, advanceState: AdvanceState) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AmgiSpacing.lg) {
                Text(word.term).amgiFont(.displayHero)
                if !word.reading.isEmpty {
                    Text(word.reading).amgiFont(.cardTitle).foregroundStyle(palette.textSecondary)
                }
                Text(word.meaning).amgiFont(.body)
                Button {
                    Task { await advance() }
                } label: {
                    HStack {
                        Label("Next word", systemImage: "arrow.forward")
                        if advanceState.isLoading { ProgressView() }
                    }
                }
                .disabled(advanceState.isLoading || !controller.canAdvance
                          || link.profileID != AccountStore.shared.selectedID)
                if controller.wordCount == 1 {
                    Text("Only one eligible word. Add more vocabulary cards to see another.")
                        .amgiFont(.caption).foregroundStyle(palette.textSecondary)
                }
                if case .failed(let message) = advanceState {
                    Text(message).foregroundStyle(palette.danger)
                    Button("Retry") { Task { await advance() } }
                }
            }
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AmgiSpacing.xl)
        }
    }

    private func load() async {
        state = .loading
        do {
            let word = try await controller.loadWord(link)
            guard !Task.isCancelled else { return }
            state = .loaded(word, .idle)
        } catch {
            guard !Task.isCancelled else { return }
            state = .failed(error.localizedDescription)
        }
    }

    private func advance() async {
        guard case .loaded(let word, let advanceState) = state, !advanceState.isLoading else { return }
        state = .loaded(word, .loading)
        if await controller.refresh(advance: true), let next = controller.currentWord {
            state = .loaded(next, .idle)
        } else if let message = controller.error {
            state = .loaded(word, .failed(message))
        } else {
            state = .loaded(word, .idle)
        }
    }
}
