//
//  Identifiers.swift
//  AnkiKit
//
//  Created by Vladimir Gusev on 07.05.2026.
//

import Foundation

/// Phantom-typed identifier wrapping the backend's `Int64` ID space.
///
/// `Tag` makes `EntityID<DeckTag>` and `EntityID<NoteTag>` distinct types
/// at the source level even though both wrap `Int64`. This prevents a
/// noteId from being passed where a deckId is expected.
/// `Identifiable` so raw ids can drive `.sheet(item:)` /
/// `.fullScreenCover(item:)` presentations without a retroactive conformance
/// in the app target.
public struct EntityID<Tag>: Hashable, Sendable, Codable, RawRepresentable, Identifiable {
    public let rawValue: Int64

    public var id: Int64 { rawValue }

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
