// AmgiApp/Sources/DeckImportModifier.swift
import SwiftUI
import UniformTypeIdentifiers

/// Self-contained deck-import flow: presents the system file importer,
/// validates the picked file, runs the import, and reports the outcome via
/// an alert. Owns its own message/alert state so the host only supplies the
/// presentation binding and a refresh hook.
private struct DeckImportModifier: ViewModifier {
    @Binding var isPresented: Bool
    let onRefresh: () -> Void

    @State private var message: String?
    @State private var showAlert = false

    func body(content: Content) -> some View {
        content
            .fileImporter(isPresented: $isPresented, allowedContentTypes: [.data]) { result in
                handleImport(result)
            }
            .alert("Import", isPresented: $showAlert) {
                Button("OK") { }
            } message: {
                Text(message ?? "")
            }
    }

}

private extension DeckImportModifier {
    func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            let ext = url.pathExtension.lowercased()
            guard ext == "apkg" || ext == "colpkg" else {
                message = "Unsupported file type. Please select an .apkg or .colpkg file."
                showAlert = true
                return
            }
            do {
                message = try ImportHelper.importPackage(from: url)
                onRefresh()
            } catch {
                message = "Import failed: \(error.localizedDescription)"
            }
            showAlert = true
        case .failure(let error):
            message = "Could not select file: \(error.localizedDescription)"
            showAlert = true
        }
    }
}

extension View {
    /// Attach the deck-import flow. `isPresented` toggles the file picker;
    /// `onRefresh` fires after a successful import so the host can reload.
    func deckImport(isPresented: Binding<Bool>, onRefresh: @escaping () -> Void) -> some View {
        modifier(DeckImportModifier(isPresented: isPresented, onRefresh: onRefresh))
    }
}
