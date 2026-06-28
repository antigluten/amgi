import SwiftUI
import UIKit
import AnkiKit
import SwiftNavigation
import SwiftUINavigation

// Two ViewModifiers split out from `DeckDetailView.body` so the SwiftUI
// type-checker doesn't blow up on a single long modifier chain. AnyView
// wrappers on the closure returns keep the outer body type stable across
// sheet/alert variants.

struct SheetCoverModifier: ViewModifier {
    let destination: Binding<DeckDetailDestination?>
    let deckId: DeckID
    let onReviewDismiss: () -> Void
    let sheetContent: (DeckDetailSheet) -> AnyView

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: destination.review) {
                ReviewView(deckId: deckId) { onReviewDismiss() }
            }
            .sheet(item: destination.sheet) { sheet in
                sheetContent(sheet)
            }
    }
}

struct AlertImporterModifier: ViewModifier {
    let destination: Binding<DeckDetailDestination?>
    let currentAlert: DeckDetailAlert?
    let alertTitle: String
    let alertActions: (DeckDetailAlert) -> AnyView
    let alertMessage: (DeckDetailAlert) -> AnyView
    let onImportResult: (Result<URL, Error>) -> Void

    func body(content: Content) -> some View {
        content
            .alert(
                alertTitle,
                isPresented: Binding(destination.alert),
                presenting: currentAlert
            ) { alert in
                alertActions(alert)
            } message: { alert in
                alertMessage(alert)
            }
            .fileImporter(
                isPresented: destination.importer,
                allowedContentTypes: [.data]
            ) { result in
                onImportResult(result)
            }
    }
}

/// Wraps `UIActivityViewController` so the deck export `.apkg` can be shared
/// (AirDrop, Files, Mail, etc.). Dismisses via `onDismiss` when the activity
/// view completes or is cancelled.
struct DeckExportShareSheet: UIViewControllerRepresentable {
    let url: URL
    let onDismiss: () -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in
            onDismiss()
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
