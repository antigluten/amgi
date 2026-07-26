#if DEBUG && canImport(SwiftUI)
import Foundation

// Sample data for SwiftUI #Preview blocks. Gated by DEBUG + canImport(SwiftUI)
// so neither release builds nor non-UI consumers (CLI, server, tests-only) pay
// for them.

extension DeckCounts {
    public static let sampleLight = DeckCounts(newCount: 8, learnCount: 3, reviewCount: 21)
    public static let sampleHeavy = DeckCounts(newCount: 142, learnCount: 17, reviewCount: 304)
}

extension DeckInfo {
    public static let sample = DeckInfo(
        id: DeckID(1),
        name: "Japanese::Vocabulary",
        counts: .sampleLight,
        isFiltered: false
    )

    public static let filtered = DeckInfo(
        id: DeckID(2),
        name: "Custom Study: Hardest cards",
        counts: .sampleLight,
        isFiltered: true
    )

    public static let empty = DeckInfo(
        id: DeckID(3),
        name: "Fresh deck",
        counts: .zero,
        isFiltered: false
    )
}

extension DeckTreeNode {
    public static let sample = DeckTreeNode(
        id: DeckID(10),
        name: "Default",
        fullName: "Default",
        counts: .sampleLight,
        isFiltered: false,
        children: []
    )

    public static let sampleTree: [DeckTreeNode] = [
        DeckTreeNode(
            id: DeckID(100),
            name: "Japanese",
            fullName: "Japanese",
            counts: .sampleHeavy,
            children: [
                DeckTreeNode(
                    id: DeckID(101),
                    name: "Vocabulary",
                    fullName: "Japanese::Vocabulary",
                    counts: .sampleLight
                ),
                DeckTreeNode(
                    id: DeckID(102),
                    name: "Grammar",
                    fullName: "Japanese::Grammar",
                    counts: DeckCounts(newCount: 2, learnCount: 0, reviewCount: 11)
                )
            ]
        ),
        DeckTreeNode(
            id: DeckID(200),
            name: "Custom Study",
            fullName: "Custom Study",
            counts: DeckCounts(newCount: 0, learnCount: 0, reviewCount: 18),
            isFiltered: true
        ),
        DeckTreeNode(
            id: DeckID(300),
            name: "Default",
            fullName: "Default",
            counts: .zero
        )
    ]

    public static let largeTree: [DeckTreeNode] = makeLargeTree()

    private static func makeLargeTree() -> [DeckTreeNode] {
        var nodes: [DeckTreeNode] = []
        for i in 1...12 {
            let counts = DeckCounts(
                newCount: (i * 3) % 17,
                learnCount: i % 5,
                reviewCount: (i * 7) % 41
            )
            var children: [DeckTreeNode] = []
            if i % 3 == 0 {
                children.append(DeckTreeNode(
                    id: DeckID(Int64(10_000 + i)),
                    name: "Sub A",
                    fullName: "Deck \(i)::Sub A",
                    counts: DeckCounts(newCount: i, learnCount: 0, reviewCount: i * 2)
                ))
                children.append(DeckTreeNode(
                    id: DeckID(Int64(20_000 + i)),
                    name: "Sub B",
                    fullName: "Deck \(i)::Sub B",
                    counts: .zero
                ))
            }
            nodes.append(DeckTreeNode(
                id: DeckID(Int64(1000 + i)),
                name: "Deck \(i)",
                fullName: "Deck \(i)",
                counts: counts,
                isFiltered: i % 6 == 0,
                children: children
            ))
        }
        return nodes
    }
}

extension ReviewCountsAndTimes {
    public static let sampleEmpty = ReviewCountsAndTimes()

    /// One year (~365 days) of varied review counts, indexed by day offset
    /// (negative integers, where 0 is today and -364 is one year ago).
    /// Deterministic — no RNG — so previews stay stable.
    public static let sampleYear: ReviewCountsAndTimes = {
        var count: [Int: Reviews] = [:]
        var time: [Int: Reviews] = [:]
        for offset in (-364...0) {
            let i = -offset
            // Skew some weekdays heavier than weekends for visual variety.
            let weekday = i % 7
            let base = (weekday == 0 || weekday == 6) ? 4 : 18
            let scatter = (i * 13) % 11
            let learn = max(0, base + scatter - 5)
            let young = max(0, base + scatter)
            let mature = max(0, base * 2 - scatter)
            let relearn = (i % 9 == 0) ? 3 : 0
            let filtered = (i % 14 == 0) ? 2 : 0
            let r = Reviews(
                learn: learn,
                relearn: relearn,
                young: young,
                mature: mature,
                filtered: filtered
            )
            count[offset] = r
            // ~6s per learn, ~4s per young, ~3s per mature (in millis)
            time[offset] = Reviews(
                learn: learn * 6_000,
                relearn: relearn * 8_000,
                young: young * 4_000,
                mature: mature * 3_000,
                filtered: filtered * 5_000
            )
        }
        return ReviewCountsAndTimes(count: count, time: time)
    }()
}
#endif
