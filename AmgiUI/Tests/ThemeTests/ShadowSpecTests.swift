//
//  ShadowSpecTests.swift
//  ThemeTests
//
//  Created by Vladimir Gusev on 14.05.2026.
//

import Foundation
import Testing
@testable import Theme

@Suite("Shadow tokens codable")
struct ShadowSpecTests {
    @Test func shadowSpecCodableRoundTrip() throws {
        let original = ShadowSpec(radius: 16, dx: 0, dy: 4, opacity: 0.06)
        let json = try JSONEncoder().encode(original)
        #expect(try JSONDecoder().decode(ShadowSpec.self, from: json) == original)
    }

    @Test func shadowSetCodableRoundTrip() throws {
        let original = ShadowSet(
            sm: ShadowSpec(radius: 2, dx: 0, dy: 1, opacity: 0.04),
            md: ShadowSpec(radius: 16, dx: 0, dy: 4, opacity: 0.06)
        )
        let json = try JSONEncoder().encode(original)
        #expect(try JSONDecoder().decode(ShadowSet.self, from: json) == original)
    }
}
