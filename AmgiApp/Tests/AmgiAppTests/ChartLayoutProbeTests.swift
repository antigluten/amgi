import AnkiKit
import Foundation
import StatsCharts
import SwiftUI
import Testing
import Theme
import UIKit
import Vision

/// Actual populated charts: bounded OCR guard plus retained visual evidence.
@MainActor @Suite(.serialized)
struct ChartLayoutProbeTests {
    @Test(arguments: [240, 320, 390])
    func populatedAxes(width: Int) async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("amgi-chart-probe")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let hours = (0..<24).map { hour in
            HoursBuckets.Hour(total: (hour + 1) * 317, correct: (hour + 1) * 231)
        }
        let buckets = HoursBuckets(oneMonth: hours, threeMonths: hours, oneYear: hours, allTime: hours)
        for size in [DynamicTypeSize.large, .xxxLarge, .accessibility3] {
            for period in [StatsPeriod.month, .all] {
                let days = period == .month ? Array(0..<31) : Array(stride(from: 0, through: 30_000, by: 1_000))
                let future = FutureDueSeries(
                    futureDue: Dictionary(uniqueKeysWithValues: days.enumerated().map { ($0.element, ($0.offset + 1) * 73) }),
                    dailyLoad: 43
                )
                let view = VStack(spacing: 16) {
                    FutureDueChart(futureDue: future, period: period)
                    HourlyChart(hours: buckets, period: period)
                }
                .environment(\.palette, .vividLight)
                .environment(\.dynamicTypeSize, size)
                .environment(\.locale, Locale(identifier: "en_US"))
                .frame(width: CGFloat(width))
                .fixedSize(horizontal: false, vertical: true)
                .background(Color.white)
                let renderer = ImageRenderer(content: view)
                renderer.scale = 2
                let image = try #require(renderer.uiImage)
                let url = directory.appendingPathComponent("\(width)-\(size)-\(period).png")
                try #require(image.pngData()).write(to: url)
                let cgImage = try #require(image.cgImage)
                // Vision must not starve concurrent main-actor tests' bounded waits.
                let lines = try await Task.detached {
                    let request = VNRecognizeTextRequest()
                    request.recognitionLevel = .accurate
                    request.recognitionLanguages = ["en-US"]
                    try VNImageRequestHandler(cgImage: cgImage).perform([request])
                    return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
                }.value
                #expect(lines.contains { $0.contains("Hourly") })
                let hourLabels = Set(["12a", "4a", "8a", "12p", "4p", "8p"])
                let visibleHours = lines.flatMap { $0.split(separator: " ").map(String.init) }
                    .filter { hourLabels.contains($0) }
                #expect(visibleHours.count >= 4) // Do not pass by hiding all axis labels.
                if size == .accessibility3 {
                    let total = future.futureDue
                        .filter { Int($0.key) < period.days }
                        .values.reduce(0) { $0 + Int($1) }
                    #expect(lines.contains(String(total)), "Footer numbers must not split into multiple lines")
                    #expect(lines.contains("Tomorrow"))
                    #expect(lines.joined(separator: " ").contains("Daily Load"))
                    #expect(lines.contains("100"), "Accuracy Y-axis must retain a readable upper tick")
                }
                if width >= 320 && period == .all {
                    #expect(lines.contains("10,000"))
                }
                // Catch the reproduced merged hour ticks and truncated axis values.
                // Screenshots remain the evidence; OCR is a bounded regression guard.
                #expect(!lines.contains {
                    $0.range(
                        of: #"(?:12|[148])[ap](?:12|[148])[ap]|[0-9ap](?:\.\.\.|…)"#,
                        options: .regularExpression
                    ) != nil
                })
                print("CHART_PROBE \(url.path) OCR=\(lines)")
            }
        }
    }
}
