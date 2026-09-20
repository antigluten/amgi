//
//  LookupRankingTests.swift
//  ReaderTests
//
//  Created by Vladimir Gusev on 13.09.2026.
//

import Reader
import Testing

struct LookupRankingTests {
    struct Case: Sendable, CustomTestStringConvertible {
        let name: String
        let entries: [DictionaryLookupEntry]
        var dictionaryOrder: [String: Int] = ["A": 0, "B": 1]
        let expected: [String]

        var testDescription: String { name }
    }

    static func entry(
        _ term: String,
        matched: String,
        dictionary: String = "A",
        frequency: Int? = nil
    ) -> DictionaryLookupEntry {
        DictionaryLookupEntry(
            term: term,
            matched: matched,
            structuredGlossaries: [DictionaryLookupGlossary(dictionary: dictionary)],
            structuredFrequencies: frequency.map {
                [DictionaryLookupFrequency(dictionary: "freq", frequencies: [.init(value: $0)])]
            } ?? []
        )
    }

    static let cases: [Case] = [
        Case(
            name: "user order wins for equal match length",
            entries: [entry("fromB", matched: "先生", dictionary: "B"),
                      entry("fromA", matched: "先生", dictionary: "A")],
            expected: ["fromA", "fromB"]
        ),
        Case(
            name: "user order wins the other way too",
            entries: [entry("fromB", matched: "先生", dictionary: "B"),
                      entry("fromA", matched: "先生", dictionary: "A")],
            dictionaryOrder: ["B": 0, "A": 1],
            expected: ["fromB", "fromA"]
        ),
        Case(
            name: "a longer match beats dictionary order",
            entries: [entry("short", matched: "先", dictionary: "A"),
                      entry("long", matched: "先生", dictionary: "B")],
            expected: ["long", "short"]
        ),
        Case(
            name: "frequency orders within one dictionary",
            entries: [entry("rare", matched: "先生", frequency: 40000),
                      entry("common", matched: "先生", frequency: 12)],
            expected: ["common", "rare"]
        ),
        Case(
            name: "missing frequency sorts after present",
            entries: [entry("unranked", matched: "先生"),
                      entry("ranked", matched: "先生", frequency: 40000)],
            expected: ["ranked", "unranked"]
        ),
        Case(
            name: "an unknown dictionary sorts last",
            entries: [entry("unknown", matched: "先生", dictionary: "Z"),
                      entry("known", matched: "先生", dictionary: "B")],
            expected: ["known", "unknown"]
        ),
        Case(
            name: "ties keep engine order",
            entries: [entry("first", matched: "先生", frequency: 12),
                      entry("second", matched: "先生", frequency: 12),
                      entry("third", matched: "先生", frequency: 12)],
            expected: ["first", "second", "third"]
        ),
        Case(
            name: "the best glossary dictionary decides for a multi-dictionary entry",
            entries: [entry("onlyB", matched: "先生", dictionary: "B"),
                      DictionaryLookupEntry(
                          term: "bothBA",
                          matched: "先生",
                          structuredGlossaries: [
                              DictionaryLookupGlossary(dictionary: "B"),
                              DictionaryLookupGlossary(dictionary: "A"),
                          ]
                      )],
            expected: ["bothBA", "onlyB"]
        ),
    ]

    @Test(arguments: cases)
    func ranks(_ c: Case) {
        let ranked = LookupRanking.rank(c.entries, dictionaryOrder: c.dictionaryOrder)
        #expect(ranked.map(\.term) == c.expected)
    }
}
