public import SwiftUI

/// Deterministic mapper from deck name to an accent `Color`.
///
/// **v1 (this file):** the tone is derived from a stable FNV-1a hash of the
/// deck name so the same deck always gets the same color until it's renamed.
/// Renames change the tone — acceptable for v1; a future migration will let
/// users pick a per-deck tone stored in an Amgi-local table (not Anki's deck
/// JSON, so it survives sync untouched).
///
/// The wheel is an 8-tone Apple system-color set chosen to match the
/// `deck.tone` field in `design/deck.jsx`.
public enum DeckTonePalette {
    public static let wheel: [Color] = [
        .red, .orange, .yellow, .green,
        .mint, .cyan, .blue, .purple,
    ]

    public static func tone(for deckName: String) -> Color {
        wheel[index(for: deckName)]
    }

    /// Visible for tests — stable hash bucket in `0..<wheel.count`.
    public static func index(for deckName: String) -> Int {
        // Deterministic non-cryptographic hash (FNV-1a 32-bit). Swift's
        // `Hashable.hashValue` is randomised per-process, which would make
        // deck tones flicker between launches.
        var hash: UInt32 = 0x811C9DC5
        for byte in deckName.utf8 {
            hash ^= UInt32(byte)
            hash = hash &* 0x01000193
        }
        return Int(hash % UInt32(wheel.count))
    }
}
