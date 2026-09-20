//
//  LookupPopupEnvironmentTests.swift
//  AppSharedTests
//
//  Created by Vladimir Gusev on 29.08.2026.
//

import Testing
import SwiftUI
@testable import AppShared

@Suite @MainActor struct LookupPopupEnvironmentTests {
    /// A feature rendering without the app root — a preview, a test host —
    /// must show nothing rather than fail. Guards the documented default.
    @Test func defaultsToNoProvider() {
        #expect(EnvironmentValues().lookupPopup == nil)
    }
}
