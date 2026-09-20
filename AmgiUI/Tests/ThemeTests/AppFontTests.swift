//
//  AppFontTests.swift
//  ThemeTests
//
//  Created by Vladimir Gusev on 14.05.2026.
//

import Testing
import SwiftUI
@testable import Theme

@Suite("AppFont")
struct AppFontTests {
    @Test func rawValues() {
        #expect(AppFont.system.rawValue == "system")
        #expect(AppFont.serif.rawValue == "serif")
    }

    @Test func allCases() {
        #expect(AppFont.allCases == [.system, .serif])
    }

    @Test func environmentDefault() {
        #expect(EnvironmentValues().appFont == .system)
    }
}
