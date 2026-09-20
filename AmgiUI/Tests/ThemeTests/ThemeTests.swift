//
//  ThemeTests.swift
//  ThemeTests
//
//  Created by Vladimir Gusev on 28.04.2026.
//

import Testing
@testable import Theme

@Suite("ThemeID and Appearance")
struct ThemeTests {
    @Test(arguments: [(ThemeID.vivid, "vivid"), (.muted, "muted"), (.sepia, "sepia")])
    func themeIDRawValueRoundTrips(id: ThemeID, raw: String) {
        #expect(id.rawValue == raw)
        #expect(ThemeID(rawValue: raw) == id)
    }

    @Test func themeIDPreservesUnknownRawValue() {
        #expect(ThemeID(rawValue: "unknown").rawValue == "unknown")
    }

    @Test func themeIDEquatable() {
        #expect(ThemeID.vivid == ThemeID(rawValue: "vivid"))
        #expect(ThemeID.vivid != ThemeID.muted)
    }

    @Test(arguments: [(Appearance.system, "system"), (.light, "light"), (.dark, "dark")])
    func appearanceRawValues(appearance: Appearance, raw: String) {
        #expect(appearance.rawValue == raw)
    }

    @Test func appearanceAllCases() {
        #expect(Appearance.allCases == [.system, .light, .dark])
    }
}
