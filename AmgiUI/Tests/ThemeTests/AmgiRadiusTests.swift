//
//  AmgiRadiusTests.swift
//  ThemeTests
//
//  Created by Vladimir Gusev on 14.07.2026.
//

import Testing
import CoreGraphics
@testable import Theme

@Suite("AmgiRadius tokens")
struct AmgiRadiusTests {
    @Test func tokenValuesMatchMinimalDesignLanguage() {
        #expect(AmgiRadius.small == 8)
        #expect(AmgiRadius.inset == 12)
        #expect(AmgiRadius.hero == 14)
        #expect(AmgiRadius.control == 10)
        #expect(AmgiRadius.pill == 28)
    }

    @Test func displayHeroTrackingTightened() {
        #expect(AmgiFont.displayHero.tracking == -0.6)
    }
}
