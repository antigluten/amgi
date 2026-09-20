//
//  DeckConfigModel+Parsing.swift
//  DecksFeature
//
//  Created by Vladimir Gusev on 20.08.2026.
//

import AnkiClients
import AnkiKit
import Dependencies
import Foundation

extension DeckConfigModel {
    func parseSteps(_ text: String) -> [Float] {
        text
            .split(whereSeparator: { $0 == " " || $0 == "," || $0 == "\n" || $0 == "\t" })
            .compactMap { token -> Float? in
                let t = String(token).lowercased()
                if t.hasSuffix("m"), let v = Float(t.dropLast()) { return v }
                if t.hasSuffix("h"), let v = Float(t.dropLast()) { return v * 60 }
                if t.hasSuffix("d"), let v = Float(t.dropLast()) { return v * 1440 }
                return Float(t)
            }
    }

    func formatSteps(_ values: [Float]) -> String {
        guard !values.isEmpty else { return "" }
        return values.map { "\(Int($0))m" }.joined(separator: " ")
    }

    func parseFloats(_ text: String) -> [Float] {
        text
            .split(whereSeparator: { $0 == " " || $0 == "," || $0 == "\n" || $0 == "\t" })
            .compactMap { Float($0) }
    }

    func formatWeights(_ values: [Float]) -> String {
        values.map { String(format: "%.4f", $0) }.joined(separator: ", ")
    }

    func currentWeights(from cfg: DeckConfig.Config) -> [Float] {
        if !cfg.fsrsParams6.isEmpty { return cfg.fsrsParams6 }
        if !cfg.fsrsParams5.isEmpty { return cfg.fsrsParams5 }
        return cfg.fsrsParams4
    }

    func effectiveParamSearch() -> String {
        let trimmed = fsrsParamSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? defaultParamSearch : trimmed
    }

    /// Heuristic mirrored from upstream Anki: only relearning steps that fit
    /// inside one day are passed to the optimizer, so a "10m 1d" relearn
    /// schedule contributes 1, not 2.
    func relearningStepsInDay(_ steps: [Float]) -> UInt32 {
        var count: UInt32 = 0
        var accumulated: Float = 0
        for step in steps {
            accumulated += step
            if accumulated >= 1440 { break }
            count += 1
        }
        return count
    }

    // MARK: - Preset CRUD
}
