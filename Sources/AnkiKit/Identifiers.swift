import Foundation

/// Phantom-typed identifier wrapping the backend's `Int64` ID space.
///
/// `Tag` makes `EntityID<DeckTag>` and `EntityID<NoteTag>` distinct types
/// at the source level even though both wrap `Int64`. This prevents a
/// noteId from being passed where a deckId is expected.
public struct EntityID<Tag>: Hashable, Sendable, Codable, RawRepresentable {
    public let rawValue: Int64

    public init(_ rawValue: Int64) {
        self.rawValue = rawValue
    }

    public init(rawValue: Int64) {
        self.rawValue = rawValue
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.rawValue = try container.decode(Int64.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public enum DeckTag {}
public enum NoteTag {}
public enum CardTag {}
public enum NotetypeTag {}
public enum DeckConfigTag {}

public typealias DeckID       = EntityID<DeckTag>
public typealias NoteID       = EntityID<NoteTag>
public typealias CardID       = EntityID<CardTag>
public typealias NotetypeID   = EntityID<NotetypeTag>
public typealias DeckConfigID = EntityID<DeckConfigTag>
