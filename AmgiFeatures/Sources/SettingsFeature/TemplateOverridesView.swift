//
//  TemplateOverridesView.swift
//  SettingsFeature
//
//  Created by Vladimir Gusev on 20.07.2026.
//

import SwiftUI
import AmgiCardWeb
import Theme
import AppCore
import AnkiClients
import AnkiKit
import Dependencies
import Sharing
import ReviewCore
// MemberImportVisibility: CardRenderEngine.displayName is a ReviewFeature extension.
import ReviewFeature

/// R11 per-template override list: each stored override as
/// "Notetype · Template — engine", swipe-to-delete. Names resolve via
/// `NotetypesClient`; an override whose notetype no longer exists shows its
/// raw key and can still be deleted.
struct TemplateOverridesView: View {
    @Shared(.appStorage(ReviewPreferences.Keys.templateRenderOverrides))
    private var overridesRaw: String = "{}"

    @Dependency(\.notetypesClient) private var notetypesClient

    @Environment(\.palette) private var palette

    /// "mid:ord" → resolved "Notetype · Template" display name.
    @State private var displayNames: [String: String] = [:]

    // Stays a `List` for `onDelete` — swipe-to-delete is the only way to
    // clear an override, so the design chrome is applied to the List rather
    // than moving these rows into a `SettingsGroup`.
    var body: some View {
        List {
            if entries.isEmpty {
                ContentUnavailableView(
                    "No Overrides",
                    systemImage: "rectangle.on.rectangle.slash",
                    description: Text("Set one from the render-mode sheet while reviewing.")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(entries, id: \.key) { entry in
                    row(for: entry)
                        .listRowBackground(palette.surfaceElevated)
                }
                .onDelete(perform: delete)
            }
        }
        .scrollContentBackground(.hidden)
        .background(palette.background)
        .navigationTitle("Template Overrides")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: overridesRaw) { await resolveNames() }
    }

    private var entries: [(key: String, engine: CardRenderEngine)] {
        TemplateRenderOverrides.entries(in: overridesRaw)
    }

    private func row(for entry: (key: String, engine: CardRenderEngine)) -> some View {
        HStack(spacing: AmgiSpacing.md) {
            SettingsIconTile(systemImage: "doc.text", tone: .neutral)
            Text(displayNames[entry.key] ?? entry.key)
                .amgiFont(.body)
                .foregroundStyle(palette.textPrimary)
                .lineLimit(1)
            Spacer(minLength: AmgiSpacing.sm)
            Text(entry.engine.displayName)
                .amgiFont(.body)
                .foregroundStyle(palette.textSecondary)
        }
    }

    private func delete(at offsets: IndexSet) {
        let keys = offsets.map { entries[$0].key }
        for key in keys {
            let updated = TemplateRenderOverrides.removing(key: key, in: overridesRaw)
            $overridesRaw.withLock { $0 = updated }
        }
    }

    private func resolveNames() async {
        var resolved = [String: String](minimumCapacity: entries.count)
        var notetypes: [Int64: Notetype?] = [:]
        for entry in entries {
            let parts = entry.key.split(separator: ":")
            guard parts.count == 2,
                  let mid = Int64(parts[0]),
                  let ord = Int(parts[1])
            else { continue }
            if notetypes[mid] == nil {
                notetypes[mid] = try? await notetypesClient.get(NotetypeID(mid))
            }
            guard let notetype = notetypes[mid] ?? nil else { continue }
            let templateName = notetype.templates.indices.contains(ord)
                ? notetype.templates[ord].name
                : "Card \(ord + 1)"
            resolved[entry.key] = "\(notetype.name) · \(templateName)"
        }
        displayNames = resolved
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        TemplateOverridesView()
    }
}
#endif
