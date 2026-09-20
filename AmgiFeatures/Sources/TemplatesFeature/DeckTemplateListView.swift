//
//  DeckTemplateListView.swift
//  TemplatesFeature
//
//  Created by Vladimir Gusev on 14.05.2026.
//

package import SwiftUI
import Theme
import UI
import AnkiClients
import AnkiKit
import Dependencies

/// Lists every notetype with quick edit/rename/delete actions. Container
/// owns the @State and presents `TemplateEditorView` as a sheet; the list
/// rows, alerts, and the editor itself live in sibling files under
/// `DeckTemplateList/`.
package struct DeckTemplateListView: View {
    @Environment(\.palette) private var palette

    @State private var model = DeckTemplateListModel()

    @State private var searchText = ""
    @State private var editorTarget: TemplateEditorTarget?
    @State private var renameTarget: NotetypeNameId?
    @State private var renameText = ""
    @State private var showRenamePrompt = false
    @State private var deleteTarget: NotetypeNameId?
    @State private var showDeleteConfirm = false

    package init() {}

    private var filteredEntries: [NotetypeNameId] {
        filterDeckTemplateEntries(model.entries, searchText: searchText)
    }

    package var body: some View {
        mainContent
            .background(palette.background)
            .navigationTitle("Card Templates")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search notetypes")
            .sheet(item: $editorTarget) { target in
                TemplateEditorView(
                    notetypeId: target.id,
                    initialTemplateIndex: target.initialTemplateIndex,
                    mode: .manager,
                    onSaved: { await model.loadTemplates() }
                )
            }
            .modifier(DeckTemplateListAlerts(
                showRenamePrompt: $showRenamePrompt,
                renameText: $renameText,
                renameTargetName: renameTarget?.name ?? "",
                onRename: { renameSelected() },
                showDeleteConfirm: $showDeleteConfirm,
                deleteTargetName: deleteTarget?.name,
                onDelete: { deleteSelected() },
                showActionError: $model.showActionError,
                actionError: model.actionError
            ))
            .task { await model.loadTemplates() }
    }


    @ViewBuilder
    private var mainContent: some View {
        if model.isLoading {
            ProgressView()
        } else if let errorMessage = model.errorMessage {
            AmgiStatusMessageView(
                title: "Could not load templates",
                message: errorMessage,
                systemImage: "exclamationmark.triangle",
                tone: .warning
            )
        } else if model.entries.isEmpty {
            ContentUnavailableView(
                "No notetypes",
                systemImage: "square.stack.3d.up.slash",
                description: Text("This collection has no notetypes yet.")
            )
        } else if filteredEntries.isEmpty {
            ContentUnavailableView.search(text: searchText)
        } else {
            NotetypeList(
                entries: filteredEntries,
                onSelect: { entry in
                    editorTarget = TemplateEditorTarget(id: entry.id, initialTemplateIndex: 0)
                },
                onRequestDelete: { entry in
                    deleteTarget = entry
                    showDeleteConfirm = true
                },
                onRequestRename: { entry in
                    renameTarget = entry
                    renameText = entry.name
                    showRenamePrompt = true
                }
            )
        }
    }

}

private extension DeckTemplateListView {
    /// Bridge the view's selection state into the model's engine action.
    func renameSelected() {
        guard let renameTarget else { return }
        Task { await model.rename(renameTarget, to: renameText) }
    }

    func deleteSelected() {
        guard let deleteTarget else { return }
        Task { await model.delete(deleteTarget) }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    let _ = prepareDependencies {
        $0.notetypesClient.listAll = {
            [
                NotetypeNameId(id: NotetypeID(1), name: "Basic"),
                NotetypeNameId(id: NotetypeID(2), name: "Basic (and reversed card)"),
                NotetypeNameId(id: NotetypeID(3), name: "Cloze"),
            ]
        }
    }
    return NavigationStack {
        DeckTemplateListView()
    }
}
#endif
