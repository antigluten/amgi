import AnkiKit
import AnkiBackend
import AnkiProto
public import Dependencies
import DependenciesMacros
import Foundation
import Logging
import SwiftProtobuf

private let logger = Logger(label: "com.ankiapp.stats.client")

extension StatsClient: DependencyKey {
    public static let liveValue: Self = {
        @Dependency(\.ankiBackend) var backend

        return Self(
            heatmap: { days in
                let graphs = try fetchGraphs(backend: backend, days: days)
                var result: [DayCount] = []
                let calendar = Calendar.current
                let today = Date()
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                for (dayOffset, reviews) in graphs.reviews.count {
                    let total = reviews.learn + reviews.relearn + reviews.young + reviews.mature + reviews.filtered
                    if total > 0 {
                        let date = calendar.date(byAdding: .day, value: Int(dayOffset), to: today)!
                        result.append(DayCount(date: formatter.string(from: date), count: Int(total)))
                    }
                }
                return result.sorted(by: { $0.date < $1.date })
            },
            forecast: { days in
                let graphs = try fetchGraphs(backend: backend, days: days)
                var result: [DayCount] = []
                let calendar = Calendar.current
                let today = Date()
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                for (dayOffset, count) in graphs.futureDue.futureDue {
                    if dayOffset >= 0 && dayOffset < Int32(days) {
                        let date = calendar.date(byAdding: .day, value: Int(dayOffset), to: today)!
                        result.append(DayCount(date: formatter.string(from: date), count: Int(count)))
                    }
                }
                return result.sorted(by: { $0.date < $1.date })
            },
            retentionRate: { days in
                let graphs = try fetchGraphs(backend: backend, days: days)
                let today = graphs.today
                guard today.answerCount > 0 else { return 0 }
                return Double(today.correctCount) / Double(today.answerCount)
            },
            todayStats: {
                let graphs = try fetchGraphs(backend: backend, days: 1)
                let today = graphs.today
                return TodayStats(
                    reviewed: Int(today.answerCount),
                    timeSpentMs: Int(today.answerMillis),
                    newCards: Int(today.learnCount),
                    learnCards: Int(today.relearnCount),
                    reviewCards: Int(today.reviewCount),
                    againCount: Int(today.answerCount) - Int(today.correctCount)
                )
            },
            cardStates: {
                let graphs = try fetchGraphs(backend: backend, days: 0)
                let counts = graphs.cardCounts.includingInactive
                return CardStateBreakdown(
                    newCount: Int(counts.newCards),
                    learningCount: Int(counts.learn + counts.relearn),
                    reviewCount: Int(counts.young + counts.mature),
                    suspendedCount: Int(counts.suspended)
                )
            },
            hourlyBreakdown: {
                let graphs = try fetchGraphs(backend: backend, days: 365)
                return graphs.hours.allTime.enumerated().map { index, hour in
                    HourCount(hour: index, count: Int(hour.total))
                }
            }
        )
    }()
}

private func fetchGraphs(backend: AnkiBackend, days: Int) throws -> Anki_Stats_GraphsResponse {
    var req = Anki_Stats_GraphsRequest()
    req.search = "deck:current"
    req.days = UInt32(days)
    return try backend.invoke(
        service: AnkiBackend.Service.stats,
        method: AnkiBackend.StatsMethod.graphs,
        request: req
    )
}
