// AmgiApp/Sources/RetroactiveIdentifiable.swift
//
// Retroactive `Identifiable` conformances so raw ids can drive
// `.sheet(item:)` / `.fullScreenCover(item:)` presentations across the app.
import AnkiKit

extension Int64: @retroactive Identifiable {
    public var id: Int64 { self }
}

extension EntityID: @retroactive Identifiable {
    public var id: Int64 { rawValue }
}
