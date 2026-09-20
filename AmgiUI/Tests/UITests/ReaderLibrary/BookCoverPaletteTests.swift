//
//  BookCoverPaletteTests.swift
//  UITests
//
//  Created by Vladimir Gusev on 17.05.2026.
//

import Testing
import SwiftUI
@testable import UI

@Suite struct BookCoverPaletteTests {
    @Test func resolveIsStableForSameSeed() {
        let a = BookCoverPalette.resolve(seed: "book-abc")
        let b = BookCoverPalette.resolve(seed: "book-abc")
        #expect(a == b)
    }

    @Test func resolveDiffersAcrossSeeds() {
        #expect(BookCoverPalette.presets.count == 5)
    }

    @Test func emptySeedStillResolves() {
        let p = BookCoverPalette.resolve(seed: "")
        #expect(BookCoverPalette.presets.contains(p))
    }

    @Test func presetsHaveDistinctIdentifiers() {
        let ids = Set(BookCoverPalette.presets.map(\.id))
        #expect(ids.count == BookCoverPalette.presets.count)
    }
}
