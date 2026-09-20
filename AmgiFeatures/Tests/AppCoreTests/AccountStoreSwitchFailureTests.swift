//
//  AccountStoreSwitchFailureTests.swift
//  AppCoreTests
//
//  Created by Vladimir Gusev on 29.08.2026.
//

import Testing
@testable import AppCore

@Suite @MainActor struct AccountStoreSwitchFailureTests {
    @Test func hasSwitchFailureIsFalseWhenNoFailure() {
        let store = AccountStore.shared
        store.switchFailure = nil
        #expect(store.hasSwitchFailure == false)
    }

    @Test func hasSwitchFailureIsTrueWhenFailureSet() {
        let store = AccountStore.shared
        store.switchFailure = "boom"
        #expect(store.hasSwitchFailure == true)
        store.switchFailure = nil
    }

    /// The alert dismisses by writing `false`; that must clear the message so
    /// the alert does not immediately re-present.
    @Test func settingFalseClearsTheFailure() {
        let store = AccountStore.shared
        store.switchFailure = "boom"
        store.hasSwitchFailure = false
        #expect(store.switchFailure == nil)
    }

    /// Writing `true` is meaningless — only the switch itself sets a message —
    /// so it must not fabricate one.
    @Test func settingTrueDoesNotFabricateAMessage() {
        let store = AccountStore.shared
        store.switchFailure = nil
        store.hasSwitchFailure = true
        #expect(store.switchFailure == nil)
    }
}
