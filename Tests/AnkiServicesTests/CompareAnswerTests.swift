//
//  CompareAnswerTests.swift
//  AnkiServicesTests
//
//  Created by Vladimir Gusev on 01.05.2026.
//

import Testing
import Dependencies
import AnkiServices

@Suite struct CompareAnswerTests {
    @Test func compareAnswerClosureExists() {
        withDependencies {
            $0.cardRenderingService.compareAnswer = { _, _, _ in "diff-html" }
        } operation: {
            @Dependency(\.cardRenderingService) var dep
            let result = try? dep.compareAnswer("a", "b", false)
            #expect(result == "diff-html")
        }
    }
}
