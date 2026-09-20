//
//  KeychainProfileScopingTests.swift
//  AmgiAppTests
//
//  Created by Vladimir Gusev on 29.07.2026.
//

import Foundation
import Testing
import AnkiSync
@testable import AmgiApp

/// Sync identity must be invisible across profiles — the shared-login bug
/// was exactly this. Serialized: the tests flip the process-wide
/// `amgi.selectedUser` anchor.
@Suite(.serialized) struct KeychainProfileScopingTests {
    private static let anchor = "amgi.selectedUser"

    private func withProfile<T>(_ id: String, _ body: () throws -> T) rethrows -> T {
        let defaults = UserDefaults.standard
        let original = defaults.string(forKey: Self.anchor)
        defaults.set(id, forKey: Self.anchor)
        defer {
            if let original {
                defaults.set(original, forKey: Self.anchor)
            } else {
                defaults.removeObject(forKey: Self.anchor)
            }
        }
        return try body()
    }

    @Test func credentialsSavedInOneProfileAreInvisibleInAnother() throws {
        try withProfile("scoping-test-a") {
            try KeychainHelper.saveHostKey("hostkey-a")
        }
        withProfile("scoping-test-b") {
            #expect(KeychainHelper.loadHostKey() == nil)
        }
        withProfile("scoping-test-a") {
            #expect(KeychainHelper.loadHostKey() == "hostkey-a")
            KeychainHelper.deleteHostKey()
            #expect(KeychainHelper.loadHostKey() == nil)
        }
    }

    @Test func deleteOnlyRemovesTheActiveProfilesItem() throws {
        try withProfile("scoping-test-a") {
            try KeychainHelper.saveEndpoint("https://a.example")
        }
        try withProfile("scoping-test-b") {
            try KeychainHelper.saveEndpoint("https://b.example")
            KeychainHelper.deleteEndpoint()
            #expect(KeychainHelper.loadEndpoint() == nil)
        }
        withProfile("scoping-test-a") {
            #expect(KeychainHelper.loadEndpoint() == "https://a.example")
            KeychainHelper.deleteEndpoint()
        }
    }
}
