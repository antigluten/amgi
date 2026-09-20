//
//  SyncActionTests.swift
//  SyncFeatureTests
//
//  Created by Vladimir Gusev on 29.08.2026.
//

import Testing
import SwiftUI
@testable import SyncFeature

@Suite @MainActor struct SyncActionTests {
    /// The default action is not installed, so a preview or test host can
    /// render the sync toolbar button without a coordinator attached.
    @Test func defaultActionIsNotInstalled() {
        #expect(EnvironmentValues().startSync.isInstalled == false)
    }

    /// Two actions carrying the SAME controller compare equal. This is the
    /// property that stops readers of \.startSync invalidating on every root
    /// body evaluation: SwiftUI compares class references by identity, and
    /// SyncFlowModifier holds one instance in @State across evaluations.
    @Test func actionsWithTheSameToastCompareEqual() {
        let toast = SyncToastController()
        #expect(SyncAction(toast: toast) == SyncAction(toast: toast))
    }

    /// Different controllers must NOT compare equal, or a real change would be
    /// silently swallowed. Guards against an `==` that returns true blindly.
    @Test func actionsWithDifferentToastsDiffer() {
        #expect(SyncAction(toast: SyncToastController()) != SyncAction(toast: SyncToastController()))
    }
}
