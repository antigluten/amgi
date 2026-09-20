//
//  BookMetaFormatters.swift
//  UI
//
//  Created by Vladimir Gusev on 17.05.2026.
//

public import Foundation

public enum BookMetaFormatters {
    public static func surname(from author: String?) -> String? {
        guard let author else { return nil }
        let trimmed = author.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed.split(whereSeparator: { $0.isWhitespace }).last.map(String.init)
    }

    /// Allocated once — this runs per library row, and `RelativeDateTimeFormatter`
    /// is expensive to construct. `nonisolated(unsafe)` because `Formatter`
    /// subclasses aren't `Sendable`; the instance is configured here and only
    /// ever read, and every caller is already on the main actor.
    nonisolated(unsafe) private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f
    }()

    public static func relativeReadingDate(_ date: Date, reference now: Date = .init()) -> String {
        let delta = now.timeIntervalSince(date)
        if delta < 60 * 60 * 24 { return "Today" }
        if delta < 60 * 60 * 48 { return "Yesterday" }

        return relativeFormatter.localizedString(for: date, relativeTo: now)
    }
}
