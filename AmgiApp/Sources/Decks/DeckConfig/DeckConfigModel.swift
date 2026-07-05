import AnkiClients
import AnkiKit
import Dependencies
import Foundation

/// Owns the per-deck study-options editing surface: the `deckClient`
/// dependency, the loaded config + context, every editable form field, and
/// all load/save/preset/FSRS I/O. The `DeckConfigView` Container binds its
/// sections to `$model.field` and translates engine outcomes into
/// `destination` transitions, so the view itself carries no `@Dependency`.
@Observable
@MainActor
final class DeckConfigModel {
    let deckId: DeckID
    let deckName: String

    @ObservationIgnored @Dependency(\.deckClient) private var deckClient

    var loaded: LoadedConfig?
    var isLoading = true
    var isSaving = false
    var loadError: String?
    var destination: DeckConfigDestination?

    var newCardsPerDay: Int32 = 20
    var reviewsPerDay: Int32 = 200
    var newCardsIgnoreReviewLimit = false
    var applyAllParentLimits = false

    var learningStepsText: String = "1m 10m"
    var graduatingGoodDays: Int32 = 1
    var graduatingEasyDays: Int32 = 4

    var relearningStepsText: String = "10m"
    var leechThreshold: Int32 = 8
    var leechAction: LeechAction = .suspend

    var fsrsEnabled = false
    var desiredRetentionPercent: Double = 90
    var historicalRetentionPercent: Double = 90
    var fsrsHealthCheck = false
    var fsrsWeightsText: String = ""
    var fsrsParamSearch: String = ""
    var isOptimizingFsrs = false

    var applyToChildren = false

    // Preset CRUD — text-field draft state for the create/rename alerts.
    // (Presentation state itself lives in `destination`.)
    var isPresetMutating = false
    var newPresetName = ""
    var renamePresetDraft = ""

    // Bury
    var buryNew = true
    var buryReviews = true
    var buryInterdayLearning = false

    // Order
    var newCardInsertOrder: NewCardInsertOrder = .due
    var newCardGatherPriority: NewCardGatherPriority = .deck
    var newCardSortOrder: NewCardSortOrder = .template
    var newMix: ReviewMix = .mixWithReviews
    var reviewOrder: ReviewCardOrder = .day
    var interdayLearningMix: ReviewMix = .mixWithReviews

    // Timer
    var showTimer = false
    var capAnswerTimeToSecs: Int32 = 60
    var stopTimerOnAnswer = true

    // Auto-Advance
    var secondsToShowQuestion: Double = 0
    var secondsToShowAnswer: Double = 0
    var questionAction: QuestionAction = .showAnswer
    var answerAction: AnswerAction = .buryCard

    // Advanced
    var maximumReviewIntervalDays: Int32 = 36500
    var intervalMultiplierPercent: Double = 100
    var hardMultiplierPercent: Double = 120
    var easyMultiplierPercent: Double = 130
    var disableAutoplay = false
    var waitForAudio = false

    // Easy Days — per-weekday FSRS workload multipliers (Mon..Sun, 50..150%).
    var easyDayPercentages: [Double] = Array(repeating: 100, count: 7)

    struct LoadedConfig {
        var config: DeckConfig
        var context: DeckConfigsForUpdate
    }

    init(deckId: DeckID, deckName: String) {
        self.deckId = deckId
        self.deckName = deckName
    }

    // MARK: - Derived presentation values

    var currentAlert: DeckConfigAlert? {
        if case .alert(let a) = destination { return a }
        return nil
    }

    var alertTitle: String {
        switch currentAlert {
        case .saveFailed: "Save failed"
        case .fsrsError: "FSRS"
        case .presetError: "Preset"
        case .createPreset: "New preset"
        case .renamePreset: "Rename preset"
        case .deletePresetConfirm: "Delete preset?"
        case nil: ""
        }
    }

    var hasLoadedConfig: Bool { loaded != nil }
    var currentPresetName: String? { loaded?.config.name }
    var deleteFallbackPresetName: String? { deleteFallbackPreset?.name }

    var presetOptions: [DeckConfigsForUpdate.ConfigWithExtra] {
        (loaded?.context.allConfig ?? [])
            .sorted { $0.config.name.localizedCaseInsensitiveCompare($1.config.name) == .orderedAscending }
    }

    var selectedPresetID: DeckConfigID { loaded?.config.id ?? DeckConfigID(0) }

    var canDeletePreset: Bool {
        // Preset id 1 is the built-in Default preset and cannot be removed.
        selectedPresetID.rawValue != 0 && selectedPresetID.rawValue != 1 && presetOptions.count > 1
    }

    var deleteFallbackPreset: DeckConfig? {
        presetOptions.first(where: { $0.config.id.rawValue == 1 && $0.config.id != selectedPresetID })?.config
            ?? presetOptions.first(where: { $0.config.id != selectedPresetID })?.config
    }

    var presetUseCount: Int {
        loaded.flatMap { l in l.context.allConfig.first(where: { $0.config.id == l.config.id })?.useCount } ?? 0
    }

    private var defaultParamSearch: String {
        let escaped = (loaded?.config.name ?? deckName)
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "preset:\"\(escaped)\" -is:suspended"
    }

    // MARK: - Load / save

    func loadConfig() async {
        isLoading = true
        loadError = nil
        do {
            let config = try await deckClient.getDeckConfig(deckId)
            let context = (try? await deckClient.fetchDeckConfigContext(deckId)) ?? fallbackContext(from: config)
            apply(config: config, context: context)
            isLoading = false
        } catch {
            loadError = "Failed to load deck options: \(error.localizedDescription)"
            isLoading = false
        }
    }

    func apply(config: DeckConfig, context: DeckConfigsForUpdate) {
        loaded = LoadedConfig(config: config, context: context)
        let cfg = config.config
        newCardsPerDay = Int32(cfg.newPerDay)
        reviewsPerDay = Int32(cfg.reviewsPerDay)
        learningStepsText = formatSteps(cfg.learnSteps)
        relearningStepsText = formatSteps(cfg.relearnSteps)
        graduatingGoodDays = Int32(cfg.graduatingIntervalGood)
        graduatingEasyDays = Int32(cfg.graduatingIntervalEasy)
        leechThreshold = Int32(max(1, cfg.leechThreshold))
        leechAction = cfg.leechAction

        newCardsIgnoreReviewLimit = context.newCardsIgnoreReviewLimit
        applyAllParentLimits = context.applyAllParentLimits
        fsrsHealthCheck = context.fsrsHealthCheck
        fsrsEnabled = context.fsrs

        if let override = context.currentDeck?.limits?.desiredRetention {
            desiredRetentionPercent = Double(override * 100)
        } else {
            desiredRetentionPercent = cfg.desiredRetention > 0 ? Double(cfg.desiredRetention * 100) : 90
        }
        historicalRetentionPercent = cfg.historicalRetention > 0 ? Double(cfg.historicalRetention * 100) : 90

        fsrsWeightsText = formatWeights(currentWeights(from: cfg))
        fsrsParamSearch = cfg.paramSearch

        buryNew = cfg.buryNew
        buryReviews = cfg.buryReviews
        buryInterdayLearning = cfg.buryInterdayLearning

        newCardInsertOrder = cfg.newCardInsertOrder
        newCardGatherPriority = cfg.newCardGatherPriority
        newCardSortOrder = cfg.newCardSortOrder
        newMix = cfg.newMix
        reviewOrder = cfg.reviewOrder
        interdayLearningMix = cfg.interdayLearningMix

        showTimer = cfg.showTimer
        capAnswerTimeToSecs = Int32(max(5, cfg.capAnswerTimeToSecs))
        stopTimerOnAnswer = cfg.stopTimerOnAnswer

        secondsToShowQuestion = Double(cfg.secondsToShowQuestion)
        secondsToShowAnswer = Double(cfg.secondsToShowAnswer)
        questionAction = cfg.questionAction
        answerAction = cfg.answerAction

        maximumReviewIntervalDays = Int32(max(1, cfg.maximumReviewInterval))
        intervalMultiplierPercent = cfg.intervalMultiplier > 0 ? Double(cfg.intervalMultiplier * 100) : 100
        hardMultiplierPercent = cfg.hardMultiplier > 0 ? Double(cfg.hardMultiplier * 100) : 120
        easyMultiplierPercent = cfg.easyMultiplier > 0 ? Double(cfg.easyMultiplier * 100) : 130
        disableAutoplay = cfg.disableAutoplay
        waitForAudio = cfg.waitForAudio

        if cfg.easyDaysPercentages.count == 7 {
            easyDayPercentages = cfg.easyDaysPercentages.map { Double($0) * 100 }
        } else {
            easyDayPercentages = Array(repeating: 100, count: 7)
        }
    }

    /// Writes the edited form back through the engine. Returns `true` when
    /// the save succeeded so the Container can dismiss; sets a `.saveFailed`
    /// alert and returns `false` otherwise.
    func saveConfig() async -> Bool {
        guard let loaded else { return false }
        isSaving = true
        defer { isSaving = false }

        var updated = loaded.config
        var cfg = updated.config
        cfg.newPerDay = Int(max(0, newCardsPerDay))
        cfg.reviewsPerDay = Int(max(0, reviewsPerDay))
        cfg.learnSteps = parseSteps(learningStepsText)
        cfg.relearnSteps = parseSteps(relearningStepsText)
        cfg.graduatingIntervalGood = Int(max(0, graduatingGoodDays))
        cfg.graduatingIntervalEasy = Int(max(0, graduatingEasyDays))
        cfg.leechThreshold = Int(max(1, leechThreshold))
        cfg.leechAction = leechAction
        cfg.desiredRetention = Float(desiredRetentionPercent / 100)
        cfg.historicalRetention = Float(historicalRetentionPercent / 100)
        cfg.paramSearch = fsrsParamSearch.trimmingCharacters(in: .whitespacesAndNewlines)

        cfg.buryNew = buryNew
        cfg.buryReviews = buryReviews
        cfg.buryInterdayLearning = buryInterdayLearning

        cfg.newCardInsertOrder = newCardInsertOrder
        cfg.newCardGatherPriority = newCardGatherPriority
        cfg.newCardSortOrder = newCardSortOrder
        cfg.newMix = newMix
        cfg.reviewOrder = reviewOrder
        cfg.interdayLearningMix = interdayLearningMix

        cfg.showTimer = showTimer
        cfg.capAnswerTimeToSecs = Int(max(5, capAnswerTimeToSecs))
        cfg.stopTimerOnAnswer = stopTimerOnAnswer

        cfg.secondsToShowQuestion = Float(max(0, secondsToShowQuestion))
        cfg.secondsToShowAnswer = Float(max(0, secondsToShowAnswer))
        cfg.questionAction = questionAction
        cfg.answerAction = answerAction

        cfg.maximumReviewInterval = Int(max(1, maximumReviewIntervalDays))
        cfg.intervalMultiplier = Float(intervalMultiplierPercent / 100)
        cfg.hardMultiplier = Float(hardMultiplierPercent / 100)
        cfg.easyMultiplier = Float(easyMultiplierPercent / 100)
        cfg.disableAutoplay = disableAutoplay
        cfg.waitForAudio = waitForAudio

        cfg.easyDaysPercentages = easyDayPercentages.map { Float(max(50, min(150, $0)) / 100) }

        if fsrsEnabled {
            let parsed = parseFloats(fsrsWeightsText)
            if !parsed.isEmpty {
                // Newer FSRS revisions write to params6; clear the older slots
                // so the backend uses the current generation.
                cfg.fsrsParams6 = parsed
                cfg.fsrsParams5 = []
                cfg.fsrsParams4 = []
            }
        } else {
            cfg.fsrsParams6 = []
            cfg.fsrsParams5 = []
            cfg.fsrsParams4 = []
        }

        updated.config = cfg

        do {
            try await deckClient.updateDeckConfig(
                deckId,
                updated,
                applyToChildren,
                fsrsEnabled,
                newCardsIgnoreReviewLimit,
                applyAllParentLimits,
                fsrsHealthCheck
            )
            return true
        } catch {
            destination = .alert(.saveFailed(error.localizedDescription))
            return false
        }
    }

    // MARK: - Helpers

    func fallbackContext(from config: DeckConfig) -> DeckConfigsForUpdate {
        let cfg = config.config
        let fsrsBacked = !cfg.fsrsParams6.isEmpty || !cfg.fsrsParams5.isEmpty || !cfg.fsrsParams4.isEmpty
        return DeckConfigsForUpdate(
            allConfig: [DeckConfigsForUpdate.ConfigWithExtra(config: config, useCount: 0)],
            currentDeck: DeckConfigsForUpdate.CurrentDeck(name: deckName, configID: config.id),
            defaults: config,
            fsrs: fsrsBacked
        )
    }

    /// Anki stores learn/relearn steps as Float minutes. Accept "1m 10m 1h 1d"
    /// shorthand on input and emit "1m 10m" on output (matching the FSRS
    /// scheduler's expected unit).
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

    func createPreset() async {
        let name = newPresetName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let base = loaded?.config else { return }
        isPresetMutating = true
        defer { isPresetMutating = false }
        do {
            try await deckClient.createDeckPreset(deckId, base, uniqueName(name), applyToChildren)
            newPresetName = ""
            await loadConfig()
        } catch {
            destination = .alert(.presetError("Failed to create preset: \(error.localizedDescription)"))
        }
    }

    func renamePreset() async {
        guard var base = loaded?.config else { return }
        let trimmed = renamePresetDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isPresetMutating = true
        defer { isPresetMutating = false }
        do {
            base.name = trimmed
            // Reuse selectDeckPreset which writes the existing config's row in
            // place — same RPC the Anki Desktop "rename preset" flow uses.
            try await deckClient.selectDeckPreset(deckId, base, applyToChildren)
            await loadConfig()
        } catch {
            destination = .alert(.presetError("Failed to rename preset: \(error.localizedDescription)"))
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

    func optimizeCurrentPreset() async {
        guard let loaded else { return }
        isOptimizingFsrs = true
        defer { isOptimizingFsrs = false }

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
            guard !result.weights.isEmpty else {
                destination = .alert(.fsrsError("Not enough review history to optimize. Try lowering historical retention or expanding the search."))
                return
            }
            fsrsWeightsText = formatWeights(result.weights.values)
            if result.healthCheck == .failed {
                destination = .alert(.fsrsError("Health check failed — review history may be inconsistent. Inspect parameters before saving."))
            }
        } catch {
            destination = .alert(.fsrsError(error.localizedDescription))
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
            destination = .alert(.fsrsError(error.localizedDescription))
        }
    }

    // MARK: - FSRS simulator entry

    func openSimulator(mode: FsrsSimulatorMode) {
        guard let loaded else { return }
        let cfg = loaded.config.config
        let editedWeights = parseFloats(fsrsWeightsText)
        let weights = editedWeights.isEmpty ? currentWeights(from: cfg) : editedWeights
        guard !weights.isEmpty else {
            destination = .alert(.fsrsError("FSRS weights are empty. Run Optimize Weights first or save the preset."))
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
        destination = .sheet(.simulator(context))
    }
}
