import SwiftUI
import AmgiCardWeb
import AmgiTheme
import AnkiClients
import AnkiKit
import Dependencies
import Sharing

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

    var body: some View {
        List {
            if entries.isEmpty {
                ContentUnavailableView(
                    "No Overrides",
                    systemImage: "rectangle.on.rectangle.slash",
                    description: Text("Set one from the render-mode sheet while reviewing.")
                )
            } else {
                ForEach(entries, id: \.key) { entry in
                    row(for: entry)
                }
                .onDelete(perform: delete)
            }
        }
        .navigationTitle("Template Overrides")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: overridesRaw) { await resolveNames() }
    }

    private var entries: [(key: String, engine: CardRenderEngine)] {
        TemplateRenderOverrides.entries(in: overridesRaw)
    }

    private func row(for entry: (key: String, engine: CardRenderEngine)) -> some View {
        HStack {
            Text(displayNames[entry.key] ?? entry.key)
                .foregroundStyle(palette.textPrimary)
                .lineLimit(1)
            Spacer()
            Text(entry.engine.displayName)
                .amgiFont(.caption)
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
        var resolved: [String: String] = [:]
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
