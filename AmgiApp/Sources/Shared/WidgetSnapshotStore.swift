// AmgiApp/Sources/Widgets/WidgetSnapshotStore.swift
import Foundation

enum WidgetSnapshotStore {
    public static let groupId = "group.com.amgiapp"

    static func write(_ snapshot: WidgetSnapshot) throws {
        guard let url = fileURL(deckId: snapshot.deckId) else {
            throw CocoaError(.fileNoSuchFile)
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)
        try data.write(to: url, options: .atomic)
    }

    static func read(deckId: Int64) -> WidgetSnapshot? {
        guard let url = fileURL(deckId: deckId) else { return nil }
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(WidgetSnapshot.self, from: data)
    }

    static func read(from url: URL) -> WidgetSnapshot? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(WidgetSnapshot.self, from: data)
    }

    /// Enumerates all snapshot files to build the deck list for the widget picker.
    static func allSnapshots() -> [WidgetSnapshot] {
        guard let container = container() else { return [] }
        let files = (try? FileManager.default.contentsOfDirectory(
            at: container,
            includingPropertiesForKeys: nil
        )) ?? []
        return files
            .filter { $0.lastPathComponent.hasPrefix("widget-snapshot-") && $0.pathExtension == "json" }
            .compactMap { read(from: $0) }
            .sorted { $0.deckName < $1.deckName }
    }
}

private extension WidgetSnapshotStore {
    static func container() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupId)
    }

    static func fileURL(deckId: Int64) -> URL? {
        container()?.appendingPathComponent("widget-snapshot-\(deckId).json")
    }
}
