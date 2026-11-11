//
//  ChartLayoutProbeTests.swift
//  StatsFeatureTests
//
//  Created by Vladimir Gusev on 25.10.2026.
//

#if canImport(UIKit)
import AnkiKit
import Foundation
import StatsCharts
import SwiftUI
import Testing
import Theme
import UIKit
import Vision

@MainActor @Suite(.serialized)
struct ChartLayoutProbeTests {
    @Test(arguments: [320, 390], [DynamicTypeSize.large, .accessibility3, .accessibility5])
    func populatedChartsStayLegible(width: Int, size: DynamicTypeSize) async throws {
        let hours = (0..<24).map { HoursBuckets.Hour(total: ($0 + 1) * 317, correct: ($0 + 1) * 231) }
        let buckets = HoursBuckets(oneMonth: hours, threeMonths: hours, oneYear: hours, allTime: hours)
        let future = FutureDueSeries(
            futureDue: Dictionary(uniqueKeysWithValues: (0..<31).map { ($0, ($0 + 1) * 73) }),
            dailyLoad: 43
        )
        let view = VStack(spacing: 16) {
            FutureDueChart(futureDue: future, period: .month)
            HourlyChart(hours: buckets, period: .month)
        }
        .environment(\.palette, .vividLight)
        .environment(\.dynamicTypeSize, size)
        .environment(\.locale, Locale(identifier: "en_US"))
        .frame(width: CGFloat(width))
        .fixedSize(horizontal: false, vertical: true)
        .background(Color.white)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        let cgImage = try #require(renderer.uiImage?.cgImage)
        // Off the main actor so Vision cannot starve other main-actor tests' bounded waits.
        let lines = try await Task.detached {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["en-US"]
            try VNImageRequestHandler(cgImage: cgImage).perform([request])
            return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
        }.value
        let text = lines.joined(separator: " ")
        #expect(text.contains("Future Due"))
        #expect(text.contains("Hourly"))
        #expect(text.contains("Tomorrow"))
        #expect(!text.contains("…") && !text.contains("..."))
        #expect(!lines.contains { $0.range(of: #"(?:12|[148])[ap]\s?(?:12|[148])[ap]"#, options: .regularExpression) != nil })
    }
}
#endif
