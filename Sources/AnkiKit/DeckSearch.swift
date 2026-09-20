//
//  DeckSearch.swift
//  AnkiKit
//
//  Created by Vladimir Gusev on 20.08.2026.
//

import Foundation

/// Anki search-query construction.
///
/// Lives in `AnkiKit` (no `AnkiClients` dependency) so the widget and the
/// watch can use it too.
public enum DeckSearch: Sendable {
    /// Builds a `deck:"..."` term for `name`, escaping the characters Anki
    /// treats specially inside a quoted term.
    ///
    /// Four call sites used to interpolate the name raw while two others
    /// each carried a private copy of this escaping, so a deck named
    /// `My "Korean" Deck` produced a malformed query and silently returned
    /// wrong stats and deck counts.
    public static func term(_ name: String) -> String {
        let escaped = name
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "deck:\"\(escaped)\""
    }
}
