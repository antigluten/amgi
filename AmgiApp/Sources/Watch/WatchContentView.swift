import AnkiKit
import SwiftUI

struct WatchContentView: View {
    var body: some View {
        NavigationStack {
            WatchDeckListView()
                .navigationDestination(for: DeckInfo.self) { deck in
                    WatchDeckDetailView(deck: deck)
                }
        }
    }
}
