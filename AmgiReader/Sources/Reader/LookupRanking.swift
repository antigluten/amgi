//
//  LookupRanking.swift
//  Reader
//
//  Created by Vladimir Gusev on 13.09.2026.
//

public enum LookupRanking {
    public static func rank(
        _ entries: [DictionaryLookupEntry],
        dictionaryOrder: [String: Int]
    ) -> [DictionaryLookupEntry] {
        entries.enumerated()
            .map { (key: sortKey($0.element, dictionaryOrder: dictionaryOrder), index: $0.offset, entry: $0.element) }
            .sorted { lhs, rhs in
                (lhs.key.matchLength, lhs.key.dictionary, lhs.key.frequency, lhs.index)
                    < (rhs.key.matchLength, rhs.key.dictionary, rhs.key.frequency, rhs.index)
            }
            .map(\.entry)
    }

    private static func sortKey(
        _ entry: DictionaryLookupEntry,
        dictionaryOrder: [String: Int]
    ) -> (matchLength: Int, dictionary: Int, frequency: Int) {
        (
            matchLength: -(entry.matched?.count ?? 0),
            dictionary: entry.structuredGlossaries
                .compactMap { dictionaryOrder[$0.dictionary] }
                .min() ?? .max,
            frequency: entry.structuredFrequencies
                .flatMap(\.frequencies)
                .map(\.value)
                .min() ?? .max
        )
    }
}
