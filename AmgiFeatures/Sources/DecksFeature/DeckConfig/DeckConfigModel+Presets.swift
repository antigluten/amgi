//
//  DeckConfigModel+Presets.swift
//  DecksFeature
//
//  Created by Vladimir Gusev on 20.08.2026.
//

import AnkiClients
import AnkiKit
import Dependencies
import Foundation

extension DeckConfigModel {
    func selectPreset(_ target: DeckConfig) async {
        isPresetMutating = true
        defer { isPresetMutating = false }
        do {
            try await deckClient.selectDeckPreset(deckId, target, applyToChildren)
            await loadConfig()
        } catch {
            destination = .alert(.presetError("Failed to switch preset: \(error.localizedDescription)"))
        }
    }

    func createPreset() async -> String? {
        let name = newPresetName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let base = loaded?.config else { return nil }
        isPresetMutating = true
        defer { isPresetMutating = false }
        do {
            try await deckClient.createDeckPreset(deckId, base, uniqueName(name), applyToChildren)
            newPresetName = ""
            await loadConfig()
            return nil
        } catch {
            return "Failed to create preset: \(error.localizedDescription)"
        }
    }

    func renamePreset() async -> String? {
        guard var base = loaded?.config else { return nil }
        let trimmed = renamePresetDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        isPresetMutating = true
        defer { isPresetMutating = false }
        do {
            base.name = trimmed
            // Reuse selectDeckPreset which writes the existing config's row in
            // place — same RPC the Anki Desktop "rename preset" flow uses.
            try await deckClient.selectDeckPreset(deckId, base, applyToChildren)
            await loadConfig()
            return nil
        } catch {
            return "Failed to rename preset: \(error.localizedDescription)"
        }
    }

    func deletePreset() async {
        guard let current = loaded?.config, let fallback = deleteFallbackPreset else { return }
        isPresetMutating = true
        defer { isPresetMutating = false }
        do {
            try await deckClient.deleteDeckPreset(deckId, current.id, fallback, applyToChildren)
            await loadConfig()
        } catch {
            destination = .alert(.presetError("Failed to delete preset: \(error.localizedDescription)"))
        }
    }

    func uniqueName(_ base: String) -> String {
        let existing = Set(presetOptions.map { $0.config.name.lowercased() })
        if !existing.contains(base.lowercased()) { return base }
        var n = 2
        while existing.contains("\(base) \(n)".lowercased()) { n += 1 }
        return "\(base) \(n)"
    }

    // MARK: - FSRS optimize

    func cancelOptimize() {
        optimizeGeneration &+= 1
        isOptimizingFsrs = false
    }

    func optimizeCurrentPreset() async {
        guard let loaded else { return }
        let generation = optimizeGeneration
        isOptimizingFsrs = true
        defer { if generation == optimizeGeneration { isOptimizingFsrs = false } }

        do {
            let cfg = loaded.config.config
            let edited = parseFloats(fsrsWeightsText)
            let request = FsrsOptimizeRequest(
                search: effectiveParamSearch(),
                currentWeights: FsrsWeights(edited.isEmpty ? currentWeights(from: cfg) : edited),
                relearningStepsPerDay: Int(relearningStepsInDay(parseSteps(relearningStepsText))),
                runHealthCheck: fsrsHealthCheck
            )

            let result = try await deckClient.computeFsrsParams(request)
            guard generation == optimizeGeneration else { return }
            guard !result.weights.isEmpty else {
                destination = .alert(.fsrsError(
                    title: "Not enough review history",
                    message: "FSRS needs more reviews before it can optimize. Try lowering historical retention or expanding the search."
                ))
                return
            }
            fsrsWeightsText = formatWeights(result.weights.values)
            if result.healthCheck == .failed {
                destination = .alert(.fsrsError(
                    title: "FSRS health check failed",
                    message: "Review history may be inconsistent. Inspect the parameters before saving."
                ))
            }
        } catch {
            guard generation == optimizeGeneration else { return }
            destination = .alert(.fsrsError(
                title: "Couldn't optimize FSRS parameters",
                message: error.localizedDescription
            ))
        }
    }

    func optimizeAllPresets() async {
        guard let loaded else { return }
        isOptimizingFsrs = true
        defer { isOptimizingFsrs = false }

        do {
            try await deckClient.optimizeFsrsPresets(deckId, loaded.config)
            await loadConfig()
        } catch {
            destination = .alert(.fsrsError(
                title: "Couldn't optimize all presets",
                message: error.localizedDescription
            ))
        }
    }

    // MARK: - FSRS simulator entry

    func openSimulator(mode: FsrsSimulatorMode) {
        guard let loaded else { return }
        let cfg = loaded.config.config
        let editedWeights = parseFloats(fsrsWeightsText)
        let weights = editedWeights.isEmpty ? currentWeights(from: cfg) : editedWeights
        guard !weights.isEmpty else {
            destination = .alert(.fsrsError(
                title: "Simulator needs FSRS weights",
                message: "This preset has no weights yet. Run Optimize Weights first, or save the preset."
            ))
            return
        }
        let context = FsrsSimulatorContext(
            mode: mode,
            weights: weights,
            desiredRetentionPercent: desiredRetentionPercent,
            historicalRetentionPercent: historicalRetentionPercent,
            newCardsPerDay: Int(max(0, newCardsPerDay)),
            reviewsPerDay: mode == .workload ? 9999 : Int(max(0, reviewsPerDay)),
            maxIntervalDays: 36500,
            search: effectiveParamSearch(),
            ignoreNewLimit: newCardsIgnoreReviewLimit,
            suspendLeeches: leechAction == .suspend,
            leechThreshold: Int(max(1, leechThreshold)),
            learningStepCount: parseSteps(learningStepsText).count,
            relearningStepCount: parseSteps(relearningStepsText).count
        )
        destination = .route(.simulator(context))
    }
}
