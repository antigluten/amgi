import SwiftUI
import AnkiKit
import AnkiClients
import AnkiProto
import Dependencies

/// Per-deck study options. First-chunk scope: Daily Limits, New Cards, Lapses,
/// and an FSRS toggle with desired/historical retention. Preset management,
/// FSRS weights/simulator, bury/timer/auto-advance, and easy-days will land in
/// follow-up commits.
struct DeckConfigView: View {
    let deckId: Int64
    let deckName: String
    let onDismiss: () -> Void

    @Dependency(\.deckClient) var deckClient

    @State private var loaded: LoadedConfig?
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var loadError: String?
    @State private var saveError: String?

    @State private var newCardsPerDay: Int32 = 20
    @State private var reviewsPerDay: Int32 = 200
    @State private var newCardsIgnoreReviewLimit = false
    @State private var applyAllParentLimits = false

    @State private var learningStepsText: String = "1m 10m"
    @State private var graduatingGoodDays: Int32 = 1
    @State private var graduatingEasyDays: Int32 = 4

    @State private var relearningStepsText: String = "10m"
    @State private var leechThreshold: Int32 = 8
    @State private var leechAction: Anki_DeckConfig_DeckConfig.Config.LeechAction = .suspend

    @State private var fsrsEnabled = false
    @State private var desiredRetentionPercent: Double = 90
    @State private var historicalRetentionPercent: Double = 90
    @State private var fsrsHealthCheck = false
    @State private var fsrsWeightsText: String = ""
    @State private var fsrsParamSearch: String = ""
    @State private var isOptimizingFsrs = false
    @State private var optimizeError: String?

    @State private var simulatorContext: FsrsSimulatorContext?

    @State private var applyToChildren = false

    // Preset CRUD
    @State private var isPresetMutating = false
    @State private var showCreatePreset = false
    @State private var newPresetName = ""
    @State private var showRenamePreset = false
    @State private var renamePresetDraft = ""
    @State private var showDeletePresetConfirm = false
    @State private var presetActionError: String?

    // Bury
    @State private var buryNew = true
    @State private var buryReviews = true
    @State private var buryInterdayLearning = false

    // Order
    @State private var newCardInsertOrder: Anki_DeckConfig_DeckConfig.Config.NewCardInsertOrder = .due
    @State private var newCardGatherPriority: Anki_DeckConfig_DeckConfig.Config.NewCardGatherPriority = .deck
    @State private var newCardSortOrder: Anki_DeckConfig_DeckConfig.Config.NewCardSortOrder = .template
    @State private var newMix: Anki_DeckConfig_DeckConfig.Config.ReviewMix = .mixWithReviews
    @State private var reviewOrder: Anki_DeckConfig_DeckConfig.Config.ReviewCardOrder = .day
    @State private var interdayLearningMix: Anki_DeckConfig_DeckConfig.Config.ReviewMix = .mixWithReviews

    // Timer
    @State private var showTimer = false
    @State private var capAnswerTimeToSecs: Int32 = 60
    @State private var stopTimerOnAnswer = true

    // Auto-Advance
    @State private var secondsToShowQuestion: Double = 0
    @State private var secondsToShowAnswer: Double = 0
    @State private var questionAction: Anki_DeckConfig_DeckConfig.Config.QuestionAction = .showAnswer
    @State private var answerAction: Anki_DeckConfig_DeckConfig.Config.AnswerAction = .buryCard

    // Advanced
    @State private var maximumReviewIntervalDays: Int32 = 36500
    @State private var intervalMultiplierPercent: Double = 100
    @State private var hardMultiplierPercent: Double = 120
    @State private var easyMultiplierPercent: Double = 130
    @State private var disableAutoplay = false
    @State private var waitForAudio = false

    // Easy Days — per-weekday FSRS workload multipliers (Mon..Sun, 50..150%).
    @State private var easyDayPercentages: [Double] = Array(repeating: 100, count: 7)

    private struct LoadedConfig {
        var config: Anki_DeckConfig_DeckConfig
        var context: Anki_DeckConfig_DeckConfigsForUpdate
    }

    var body: some View {
        formContent
            .navigationTitle("Deck Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await saveConfig() } }
                        .disabled(loaded == nil || isSaving)
                }
            }
            .modifier(DeckConfigAlerts(
                saveError: $saveError,
                optimizeError: $optimizeError,
                presetActionError: $presetActionError,
                showCreatePreset: $showCreatePreset,
                newPresetName: $newPresetName,
                onCreate: { Task { await createPreset() } },
                showRenamePreset: $showRenamePreset,
                renamePresetDraft: $renamePresetDraft,
                onRename: { Task { await renamePreset() } },
                showDeletePresetConfirm: $showDeletePresetConfirm,
                onDelete: { Task { await deletePreset() } },
                deletingPresetName: loaded?.config.name,
                fallbackPresetName: deleteFallbackPreset?.name
            ))
            .sheet(item: $simulatorContext) { context in
                FsrsSimulatorView(context: context) { simulatorContext = nil }
            }
            .task { await loadConfig() }
    }

    @ViewBuilder
    private var formContent: some View {
        Form {
            if isLoading {
                Section { ProgressView().frame(maxWidth: .infinity) }
            } else if let loadError {
                Section {
                    Text(loadError).foregroundStyle(.red)
                    Button("Retry") { Task { await loadConfig() } }
                }
            } else {
                presetSection
                dailyLimitsSection
                newCardsSection
                lapsesSection
                orderSection
                burySection
                timerSection
                autoAdvanceSection
                advancedSection
                fsrsSection
                easyDaysSection
                applySection
            }
        }
    }

    private var presetOptions: [Anki_DeckConfig_DeckConfigsForUpdate.ConfigWithExtra] {
        (loaded?.context.allConfig ?? [])
            .sorted { $0.config.name.localizedCaseInsensitiveCompare($1.config.name) == .orderedAscending }
    }

    private var selectedPresetID: Int64 { loaded?.config.id ?? 0 }

    private var canDeletePreset: Bool {
        // Preset id 1 is the built-in Default preset and cannot be removed.
        selectedPresetID != 0 && selectedPresetID != 1 && presetOptions.count > 1
    }

    private var deleteFallbackPreset: Anki_DeckConfig_DeckConfig? {
        presetOptions.first(where: { $0.config.id == 1 && $0.config.id != selectedPresetID })?.config
            ?? presetOptions.first(where: { $0.config.id != selectedPresetID })?.config
    }

    private var presetUseCount: UInt32 {
        loaded.flatMap { l in l.context.allConfig.first(where: { $0.config.id == l.config.id })?.useCount } ?? 0
    }

    private var presetSection: some View {
        Section("Preset") {
            LabeledContent("Preset") {
                Menu {
                    Picker("Preset", selection: Binding(
                        get: { selectedPresetID },
                        set: { newID in
                            guard newID != selectedPresetID,
                                  let target = presetOptions.first(where: { $0.config.id == newID })?.config
                            else { return }
                            Task { await selectPreset(target) }
                        }
                    )) {
                        ForEach(presetOptions, id: \.config.id) { option in
                            Text(option.config.name).tag(option.config.id)
                        }
                    }
                } label: {
                    HStack {
                        Text(loaded?.config.name ?? "—").foregroundStyle(.primary)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(isPresetMutating || presetOptions.isEmpty)
            }

            LabeledContent("Used by") {
                Text("\(presetUseCount) deck\(presetUseCount == 1 ? "" : "s")")
                    .foregroundStyle(.secondary)
            }

            Menu {
                Button {
                    newPresetName = ""
                    showCreatePreset = true
                } label: {
                    Label("Add preset…", systemImage: "plus")
                }
                Button {
                    renamePresetDraft = loaded?.config.name ?? ""
                    showRenamePreset = true
                } label: {
                    Label("Rename…", systemImage: "pencil")
                }
                .disabled(loaded == nil)
                Button(role: .destructive) {
                    showDeletePresetConfirm = true
                } label: {
                    Label("Delete preset", systemImage: "trash")
                }
                .disabled(!canDeletePreset)
            } label: {
                if isPresetMutating {
                    HStack { ProgressView().controlSize(.small); Text("Working…") }
                } else {
                    Label("Manage Preset", systemImage: "slider.horizontal.below.rectangle")
                }
            }
            .disabled(isPresetMutating)
        }
    }

    private var dailyLimitsSection: some View {
        Section("Daily Limits") {
            Stepper("New cards/day: \(newCardsPerDay)", value: $newCardsPerDay, in: 0...9999)
            Stepper("Reviews/day: \(reviewsPerDay)", value: $reviewsPerDay, in: 0...9999)
            Toggle("New cards ignore review limit", isOn: $newCardsIgnoreReviewLimit)
            Toggle("Apply all parent limits", isOn: $applyAllParentLimits)
        }
    }

    private var newCardsSection: some View {
        Section("New Cards") {
            LabeledContent("Learning steps") {
                TextField("1m 10m", text: $learningStepsText)
                    .multilineTextAlignment(.trailing)
                    .font(.body.monospaced())
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
            Stepper("Graduating interval: \(graduatingGoodDays)d", value: $graduatingGoodDays, in: 0...365)
            Stepper("Easy interval: \(graduatingEasyDays)d", value: $graduatingEasyDays, in: 0...365)
        }
    }

    private var lapsesSection: some View {
        Section("Lapses") {
            LabeledContent("Relearning steps") {
                TextField("10m", text: $relearningStepsText)
                    .multilineTextAlignment(.trailing)
                    .font(.body.monospaced())
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
            Stepper("Leech threshold: \(leechThreshold)", value: $leechThreshold, in: 1...9999)
            Picker("Leech action", selection: $leechAction) {
                Text("Suspend card").tag(Anki_DeckConfig_DeckConfig.Config.LeechAction.suspend)
                Text("Tag only").tag(Anki_DeckConfig_DeckConfig.Config.LeechAction.tagOnly)
            }
        }
    }

    private var orderSection: some View {
        Section("Order") {
            Picker("New card insert order", selection: $newCardInsertOrder) {
                Text("Sequential (oldest first)").tag(Anki_DeckConfig_DeckConfig.Config.NewCardInsertOrder.due)
                Text("Random").tag(Anki_DeckConfig_DeckConfig.Config.NewCardInsertOrder.random)
            }
            Picker("New gather priority", selection: $newCardGatherPriority) {
                Text("Deck").tag(Anki_DeckConfig_DeckConfig.Config.NewCardGatherPriority.deck)
                Text("Deck, then random notes").tag(Anki_DeckConfig_DeckConfig.Config.NewCardGatherPriority.deckThenRandomNotes)
                Text("Position — lowest first").tag(Anki_DeckConfig_DeckConfig.Config.NewCardGatherPriority.lowestPosition)
                Text("Position — highest first").tag(Anki_DeckConfig_DeckConfig.Config.NewCardGatherPriority.highestPosition)
                Text("Random notes").tag(Anki_DeckConfig_DeckConfig.Config.NewCardGatherPriority.randomNotes)
                Text("Random cards").tag(Anki_DeckConfig_DeckConfig.Config.NewCardGatherPriority.randomCards)
            }
            Picker("New card sort order", selection: $newCardSortOrder) {
                Text("Card template, then gather order").tag(Anki_DeckConfig_DeckConfig.Config.NewCardSortOrder.template)
                Text("Gather order").tag(Anki_DeckConfig_DeckConfig.Config.NewCardSortOrder.noSort)
                Text("Card template, then random").tag(Anki_DeckConfig_DeckConfig.Config.NewCardSortOrder.templateThenRandom)
                Text("Random note, then template").tag(Anki_DeckConfig_DeckConfig.Config.NewCardSortOrder.randomNoteThenTemplate)
                Text("Random").tag(Anki_DeckConfig_DeckConfig.Config.NewCardSortOrder.randomCard)
            }
            Picker("New/review mix", selection: $newMix) {
                Text("Mix with reviews").tag(Anki_DeckConfig_DeckConfig.Config.ReviewMix.mixWithReviews)
                Text("After reviews").tag(Anki_DeckConfig_DeckConfig.Config.ReviewMix.afterReviews)
                Text("Before reviews").tag(Anki_DeckConfig_DeckConfig.Config.ReviewMix.beforeReviews)
            }
            Picker("Review order", selection: $reviewOrder) {
                Text("Mixed by day").tag(Anki_DeckConfig_DeckConfig.Config.ReviewCardOrder.day)
                Text("Day, then deck").tag(Anki_DeckConfig_DeckConfig.Config.ReviewCardOrder.dayThenDeck)
                Text("Deck, then day").tag(Anki_DeckConfig_DeckConfig.Config.ReviewCardOrder.deckThenDay)
                Text("Intervals — ascending").tag(Anki_DeckConfig_DeckConfig.Config.ReviewCardOrder.intervalsAscending)
                Text("Intervals — descending").tag(Anki_DeckConfig_DeckConfig.Config.ReviewCardOrder.intervalsDescending)
                Text("Retrievability — descending").tag(Anki_DeckConfig_DeckConfig.Config.ReviewCardOrder.retrievabilityDescending)
                Text("Random").tag(Anki_DeckConfig_DeckConfig.Config.ReviewCardOrder.random)
            }
            Picker("Interday learning mix", selection: $interdayLearningMix) {
                Text("Mix with reviews").tag(Anki_DeckConfig_DeckConfig.Config.ReviewMix.mixWithReviews)
                Text("After reviews").tag(Anki_DeckConfig_DeckConfig.Config.ReviewMix.afterReviews)
                Text("Before reviews").tag(Anki_DeckConfig_DeckConfig.Config.ReviewMix.beforeReviews)
            }
        }
    }

    private var burySection: some View {
        Section("Bury siblings") {
            Toggle("Bury new siblings", isOn: $buryNew)
            Toggle("Bury review siblings", isOn: $buryReviews)
            Toggle("Bury interday-learning siblings", isOn: $buryInterdayLearning)
        }
    }

    private var timerSection: some View {
        Section("Answer timer") {
            Toggle("Show answer timer", isOn: $showTimer)
            Stepper("Max answer seconds: \(capAnswerTimeToSecs)", value: $capAnswerTimeToSecs, in: 5...600, step: 5)
            Toggle("Stop timer on answer", isOn: $stopTimerOnAnswer)
        }
    }

    private var autoAdvanceSection: some View {
        Section("Auto-advance") {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Seconds to show question")
                    Spacer()
                    Text(String(format: "%.1f s", secondsToShowQuestion)).foregroundStyle(.secondary)
                }
                Slider(value: $secondsToShowQuestion, in: 0...60, step: 0.5)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Seconds to show answer")
                    Spacer()
                    Text(String(format: "%.1f s", secondsToShowAnswer)).foregroundStyle(.secondary)
                }
                Slider(value: $secondsToShowAnswer, in: 0...60, step: 0.5)
            }
            Picker("After question", selection: $questionAction) {
                Text("Show answer").tag(Anki_DeckConfig_DeckConfig.Config.QuestionAction.showAnswer)
                Text("Show reminder").tag(Anki_DeckConfig_DeckConfig.Config.QuestionAction.showReminder)
            }
            Picker("After answer", selection: $answerAction) {
                Text("Bury card").tag(Anki_DeckConfig_DeckConfig.Config.AnswerAction.buryCard)
                Text("Answer Again").tag(Anki_DeckConfig_DeckConfig.Config.AnswerAction.answerAgain)
                Text("Answer Hard").tag(Anki_DeckConfig_DeckConfig.Config.AnswerAction.answerHard)
                Text("Answer Good").tag(Anki_DeckConfig_DeckConfig.Config.AnswerAction.answerGood)
                Text("Show reminder").tag(Anki_DeckConfig_DeckConfig.Config.AnswerAction.showReminder)
            }
        }
    }

    private var advancedSection: some View {
        Section("Advanced (SM-2)") {
            Stepper("Maximum review interval: \(maximumReviewIntervalDays)d", value: $maximumReviewIntervalDays, in: 1...36500, step: 30)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Interval multiplier")
                    Spacer()
                    Text("\(Int(intervalMultiplierPercent))%").foregroundStyle(.secondary)
                }
                Slider(value: $intervalMultiplierPercent, in: 50...200, step: 1)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Hard multiplier")
                    Spacer()
                    Text("\(Int(hardMultiplierPercent))%").foregroundStyle(.secondary)
                }
                Slider(value: $hardMultiplierPercent, in: 80...200, step: 1)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Easy multiplier")
                    Spacer()
                    Text("\(Int(easyMultiplierPercent))%").foregroundStyle(.secondary)
                }
                Slider(value: $easyMultiplierPercent, in: 100...300, step: 1)
            }
            Toggle("Disable autoplay audio", isOn: $disableAutoplay)
            Toggle("Wait for audio before answering", isOn: $waitForAudio)
        }
    }

    private var fsrsSection: some View {
        Section("FSRS") {
            Toggle("Enable FSRS", isOn: $fsrsEnabled)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Desired retention")
                    Spacer()
                    Text("\(Int(desiredRetentionPercent))%").foregroundStyle(.secondary)
                }
                Slider(value: $desiredRetentionPercent, in: 70...97, step: 1)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Historical retention")
                    Spacer()
                    Text("\(Int(historicalRetentionPercent))%").foregroundStyle(.secondary)
                }
                Slider(value: $historicalRetentionPercent, in: 70...100, step: 1)
            }
            Toggle("Run FSRS health check on save", isOn: $fsrsHealthCheck)

            if fsrsEnabled {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Weights").font(.subheadline)
                    TextField(
                        "Space- or comma-separated parameters",
                        text: $fsrsWeightsText,
                        axis: .vertical
                    )
                    .lineLimit(2...6)
                    .font(.caption.monospaced())
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                }

                Button {
                    Task { await optimizeCurrentPreset() }
                } label: {
                    HStack {
                        if isOptimizingFsrs { ProgressView().controlSize(.small) }
                        Text(isOptimizingFsrs ? "Optimizing…" : "Optimize Weights")
                    }
                }
                .disabled(isOptimizingFsrs)

                Button {
                    openSimulator(mode: .review)
                } label: {
                    Label("Open FSRS Simulator", systemImage: "chart.line.uptrend.xyaxis")
                }
                .disabled(isOptimizingFsrs)

                Button {
                    openSimulator(mode: .workload)
                } label: {
                    Label("Help Me Decide (Workload)", systemImage: "scale.3d")
                }
                .disabled(isOptimizingFsrs)

                Button {
                    Task { await optimizeAllPresets() }
                } label: {
                    HStack {
                        if isOptimizingFsrs { ProgressView().controlSize(.small) }
                        Text("Optimize All Presets")
                    }
                }
                .disabled(isOptimizingFsrs)
            }
        }
    }

    private var easyDaysSection: some View {
        // FSRS interprets these as per-weekday workload multipliers; only
        // shown when FSRS is enabled, matching Anki desktop's gating.
        Section {
            if fsrsEnabled {
                ForEach(0..<7, id: \.self) { idx in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(Self.weekdayLabel(idx))
                            Spacer()
                            Text("\(Int(easyDayPercentages[idx]))%").foregroundStyle(.secondary)
                        }
                        Slider(
                            value: Binding(
                                get: { easyDayPercentages[idx] },
                                set: { easyDayPercentages[idx] = $0 }
                            ),
                            in: 50...150,
                            step: 5
                        )
                    }
                }
            } else {
                Text("Enable FSRS to configure Easy Days.")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Easy Days")
        } footer: {
            Text("Reduce the daily workload on specific weekdays. 100% means a normal day; lower values back off reviews on that day.")
        }
    }

    /// Anki stores easyDaysPercentages indexed Mon=0..Sun=6. Use fixed
    /// short labels rather than `Calendar.shortWeekdaySymbols` so the UI
    /// order matches the underlying storage regardless of locale.
    private static func weekdayLabel(_ idx: Int) -> String {
        ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"][idx]
    }

    private var applySection: some View {
        Section {
            Toggle("Apply to subdecks", isOn: $applyToChildren)
        } footer: {
            Text("Settings will be applied to this deck and any nested subdecks that share its preset.")
        }
    }

    // MARK: - Load / Save

    private func loadConfig() async {
        isLoading = true
        loadError = nil
        do {
            let config = try deckClient.getDeckConfig(deckId)
            let context = (try? deckClient.fetchDeckConfigContext(deckId)) ?? fallbackContext(from: config)
            await MainActor.run {
                apply(config: config, context: context)
                isLoading = false
            }
        } catch {
            await MainActor.run {
                loadError = "Failed to load deck options: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }

    private func apply(config: Anki_DeckConfig_DeckConfig, context: Anki_DeckConfig_DeckConfigsForUpdate) {
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

        if context.hasCurrentDeck,
           context.currentDeck.hasLimits,
           context.currentDeck.limits.hasDesiredRetention {
            desiredRetentionPercent = Double(context.currentDeck.limits.desiredRetention * 100)
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

    private func saveConfig() async {
        guard let loaded else { return }
        isSaving = true
        defer { isSaving = false }

        var updated = loaded.config
        var cfg = updated.config
        cfg.newPerDay = UInt32(max(0, newCardsPerDay))
        cfg.reviewsPerDay = UInt32(max(0, reviewsPerDay))
        cfg.learnSteps = parseSteps(learningStepsText)
        cfg.relearnSteps = parseSteps(relearningStepsText)
        cfg.graduatingIntervalGood = UInt32(max(0, graduatingGoodDays))
        cfg.graduatingIntervalEasy = UInt32(max(0, graduatingEasyDays))
        cfg.leechThreshold = UInt32(max(1, leechThreshold))
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
        cfg.capAnswerTimeToSecs = UInt32(max(5, capAnswerTimeToSecs))
        cfg.stopTimerOnAnswer = stopTimerOnAnswer

        cfg.secondsToShowQuestion = Float(max(0, secondsToShowQuestion))
        cfg.secondsToShowAnswer = Float(max(0, secondsToShowAnswer))
        cfg.questionAction = questionAction
        cfg.answerAction = answerAction

        cfg.maximumReviewInterval = UInt32(max(1, maximumReviewIntervalDays))
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
            try deckClient.updateDeckConfig(
                deckId,
                updated,
                applyToChildren,
                fsrsEnabled,
                newCardsIgnoreReviewLimit,
                applyAllParentLimits,
                fsrsHealthCheck
            )
            onDismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }

    // MARK: - Helpers

    private func fallbackContext(from config: Anki_DeckConfig_DeckConfig) -> Anki_DeckConfig_DeckConfigsForUpdate {
        var context = Anki_DeckConfig_DeckConfigsForUpdate()
        var withExtra = Anki_DeckConfig_DeckConfigsForUpdate.ConfigWithExtra()
        withExtra.config = config
        withExtra.useCount = 0
        context.allConfig = [withExtra]
        context.defaults = config
        var current = Anki_DeckConfig_DeckConfigsForUpdate.CurrentDeck()
        current.name = deckName
        current.configID = config.id
        context.currentDeck = current
        let cfg = config.config
        context.fsrs = !cfg.fsrsParams6.isEmpty || !cfg.fsrsParams5.isEmpty || !cfg.fsrsParams4.isEmpty
        return context
    }

    /// Anki stores learn/relearn steps as Float minutes. Accept "1m 10m 1h 1d"
    /// shorthand on input and emit "1m 10m" on output (matching the FSRS
    /// scheduler's expected unit).
    private func parseSteps(_ text: String) -> [Float] {
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

    private func formatSteps(_ values: [Float]) -> String {
        guard !values.isEmpty else { return "" }
        return values.map { "\(Int($0))m" }.joined(separator: " ")
    }

    private func parseFloats(_ text: String) -> [Float] {
        text
            .split(whereSeparator: { $0 == " " || $0 == "," || $0 == "\n" || $0 == "\t" })
            .compactMap { Float($0) }
    }

    private func formatWeights(_ values: [Float]) -> String {
        values.map { String(format: "%.4f", $0) }.joined(separator: ", ")
    }

    private func currentWeights(from cfg: Anki_DeckConfig_DeckConfig.Config) -> [Float] {
        if !cfg.fsrsParams6.isEmpty { return cfg.fsrsParams6 }
        if !cfg.fsrsParams5.isEmpty { return cfg.fsrsParams5 }
        return cfg.fsrsParams4
    }

    private var defaultParamSearch: String {
        let escaped = (loaded?.config.name ?? deckName)
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "preset:\"\(escaped)\" -is:suspended"
    }

    private func effectiveParamSearch() -> String {
        let trimmed = fsrsParamSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? defaultParamSearch : trimmed
    }

    /// Heuristic mirrored from upstream Anki: only relearning steps that fit
    /// inside one day are passed to the optimizer, so a "10m 1d" relearn
    /// schedule contributes 1, not 2.
    private func relearningStepsInDay(_ steps: [Float]) -> UInt32 {
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

    private func selectPreset(_ target: Anki_DeckConfig_DeckConfig) async {
        isPresetMutating = true
        defer { isPresetMutating = false }
        do {
            try deckClient.selectDeckPreset(deckId, target, applyToChildren)
            await loadConfig()
        } catch {
            presetActionError = "Failed to switch preset: \(error.localizedDescription)"
        }
    }

    private func createPreset() async {
        let name = newPresetName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let base = loaded?.config else { return }
        isPresetMutating = true
        defer { isPresetMutating = false }
        do {
            try deckClient.createDeckPreset(deckId, base, uniqueName(name), applyToChildren)
            newPresetName = ""
            await loadConfig()
        } catch {
            presetActionError = "Failed to create preset: \(error.localizedDescription)"
        }
    }

    private func renamePreset() async {
        guard var base = loaded?.config else { return }
        let trimmed = renamePresetDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isPresetMutating = true
        defer { isPresetMutating = false }
        do {
            base.name = trimmed
            // Reuse selectDeckPreset which writes the existing config's row in
            // place — same RPC the Anki Desktop "rename preset" flow uses.
            try deckClient.selectDeckPreset(deckId, base, applyToChildren)
            await loadConfig()
        } catch {
            presetActionError = "Failed to rename preset: \(error.localizedDescription)"
        }
    }

    private func deletePreset() async {
        guard let current = loaded?.config, let fallback = deleteFallbackPreset else { return }
        isPresetMutating = true
        defer { isPresetMutating = false }
        do {
            try deckClient.deleteDeckPreset(deckId, current.id, fallback, applyToChildren)
            await loadConfig()
        } catch {
            presetActionError = "Failed to delete preset: \(error.localizedDescription)"
        }
    }

    private func uniqueName(_ base: String) -> String {
        let existing = Set(presetOptions.map { $0.config.name.lowercased() })
        if !existing.contains(base.lowercased()) { return base }
        var n = 2
        while existing.contains("\(base) \(n)".lowercased()) { n += 1 }
        return "\(base) \(n)"
    }

    // MARK: - FSRS optimize

    private func optimizeCurrentPreset() async {
        guard let loaded else { return }
        isOptimizingFsrs = true
        defer { isOptimizingFsrs = false }

        do {
            let cfg = loaded.config.config
            var req = Anki_Scheduler_ComputeFsrsParamsRequest()
            req.search = effectiveParamSearch()
            let edited = parseFloats(fsrsWeightsText)
            req.currentParams = edited.isEmpty ? currentWeights(from: cfg) : edited
            req.numOfRelearningSteps = relearningStepsInDay(parseSteps(relearningStepsText))
            req.healthCheck = fsrsHealthCheck

            let response = try deckClient.computeFsrsParams(req)
            guard !response.params.isEmpty else {
                optimizeError = "Not enough review history to optimize. Try lowering historical retention or expanding the search."
                return
            }
            fsrsWeightsText = formatWeights(response.params)
            if response.hasHealthCheckPassed && !response.healthCheckPassed {
                optimizeError = "Health check failed — review history may be inconsistent. Inspect parameters before saving."
            }
        } catch {
            optimizeError = error.localizedDescription
        }
    }

    private func optimizeAllPresets() async {
        guard let loaded else { return }
        isOptimizingFsrs = true
        defer { isOptimizingFsrs = false }

        do {
            try deckClient.optimizeFsrsPresets(deckId, loaded.config)
            await loadConfig()
        } catch {
            optimizeError = error.localizedDescription
        }
    }

    // MARK: - FSRS simulator entry

    private func openSimulator(mode: FsrsSimulatorMode) {
        guard let loaded else { return }
        let cfg = loaded.config.config
        let editedWeights = parseFloats(fsrsWeightsText)
        let weights = editedWeights.isEmpty ? currentWeights(from: cfg) : editedWeights
        guard !weights.isEmpty else {
            optimizeError = "FSRS weights are empty. Run Optimize Weights first or save the preset."
            return
        }
        simulatorContext = FsrsSimulatorContext(
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
    }
}

// MARK: - Alert composition

/// Stitches every alert and error sheet onto the deck-options form. Pulled out
/// so the main `body` stays under the SwiftUI type-checker's complexity
/// budget — adding more than ~3 alerts inline blew past it.
private struct DeckConfigAlerts: ViewModifier {
    @Binding var saveError: String?
    @Binding var optimizeError: String?
    @Binding var presetActionError: String?

    @Binding var showCreatePreset: Bool
    @Binding var newPresetName: String
    let onCreate: () -> Void

    @Binding var showRenamePreset: Bool
    @Binding var renamePresetDraft: String
    let onRename: () -> Void

    @Binding var showDeletePresetConfirm: Bool
    let onDelete: () -> Void
    let deletingPresetName: String?
    let fallbackPresetName: String?

    func body(content: Content) -> some View {
        content
            .alert(
                "Save failed",
                isPresented: Binding(
                    get: { saveError != nil },
                    set: { if !$0 { saveError = nil } }
                ),
                presenting: saveError
            ) { _ in
                Button("OK", role: .cancel) {}
            } message: { Text($0) }
            .alert(
                "FSRS",
                isPresented: Binding(
                    get: { optimizeError != nil },
                    set: { if !$0 { optimizeError = nil } }
                ),
                presenting: optimizeError
            ) { _ in
                Button("OK", role: .cancel) {}
            } message: { Text($0) }
            .alert(
                "Preset",
                isPresented: Binding(
                    get: { presetActionError != nil },
                    set: { if !$0 { presetActionError = nil } }
                ),
                presenting: presetActionError
            ) { _ in
                Button("OK", role: .cancel) {}
            } message: { Text($0) }
            .alert("New preset", isPresented: $showCreatePreset) {
                TextField("Preset name", text: $newPresetName)
                    .autocorrectionDisabled()
                Button("Create") { onCreate() }
                    .disabled(newPresetName.trimmingCharacters(in: .whitespaces).isEmpty)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("New preset will be cloned from the current one and selected for this deck.")
            }
            .alert("Rename preset", isPresented: $showRenamePreset) {
                TextField("Preset name", text: $renamePresetDraft)
                    .autocorrectionDisabled()
                Button("Save") { onRename() }
                    .disabled(renamePresetDraft.trimmingCharacters(in: .whitespaces).isEmpty)
                Button("Cancel", role: .cancel) {}
            }
            .alert("Delete preset?", isPresented: $showDeletePresetConfirm) {
                Button("Delete", role: .destructive) { onDelete() }
                Button("Cancel", role: .cancel) {}
            } message: {
                if let name = deletingPresetName, let fallback = fallbackPresetName {
                    Text("\"\(name)\" will be removed and decks using it will switch to \"\(fallback)\".")
                } else {
                    Text("This preset will be removed.")
                }
            }
    }
}

// MARK: - FSRS Simulator

enum FsrsSimulatorMode: String, Identifiable, CaseIterable {
    case review
    case workload
    var id: String { rawValue }
}

struct FsrsSimulatorContext: Identifiable {
    let id = UUID()
    var mode: FsrsSimulatorMode
    var weights: [Float]
    var desiredRetentionPercent: Double
    var historicalRetentionPercent: Double
    var newCardsPerDay: Int
    var reviewsPerDay: Int
    var maxIntervalDays: Int
    var search: String
    var ignoreNewLimit: Bool
    var suspendLeeches: Bool
    var leechThreshold: Int
    var learningStepCount: Int
    var relearningStepCount: Int
}

struct FsrsSimulatorView: View {
    @State var context: FsrsSimulatorContext
    let onDismiss: () -> Void

    @Dependency(\.deckClient) var deckClient

    @State private var daysToSimulate = 365
    @State private var additionalCards = 0
    @State private var isRunning = false
    @State private var summary: [(label: String, value: String)] = []
    @State private var workloadRows: [(label: String, value: String)] = []
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Mode", selection: $context.mode) {
                        Text("Review").tag(FsrsSimulatorMode.review)
                        Text("Workload").tag(FsrsSimulatorMode.workload)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Settings") {
                    Stepper("Days: \(daysToSimulate)", value: $daysToSimulate, in: 30...3650, step: 30)
                    Stepper("Additional cards: \(additionalCards)", value: $additionalCards, in: 0...100000, step: 100)
                    if context.mode == .review {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Desired retention")
                                Spacer()
                                Text("\(Int(context.desiredRetentionPercent))%").foregroundStyle(.secondary)
                            }
                            Slider(value: $context.desiredRetentionPercent, in: 70...99, step: 1)
                        }
                    }
                    Stepper("New/day: \(context.newCardsPerDay)", value: $context.newCardsPerDay, in: 0...9999)
                    Stepper("Reviews/day: \(context.reviewsPerDay)", value: $context.reviewsPerDay, in: 0...9999)
                    LabeledContent("Search") {
                        TextField("preset:\"…\" -is:suspended", text: $context.search)
                            .multilineTextAlignment(.trailing)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                }

                Section {
                    Button {
                        Task { await run() }
                    } label: {
                        HStack {
                            if isRunning { ProgressView().controlSize(.small) }
                            Text(isRunning ? "Running…" : "Run Simulation")
                        }
                    }
                    .disabled(isRunning)
                }

                if !summary.isEmpty {
                    Section("Summary") {
                        ForEach(summary, id: \.label) { item in
                            LabeledContent(item.label, value: item.value)
                        }
                    }
                }

                if !workloadRows.isEmpty {
                    Section("Retention vs cost") {
                        ForEach(workloadRows, id: \.label) { row in
                            LabeledContent(row.label, value: row.value)
                        }
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("FSRS Simulator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onDismiss() }
                }
            }
        }
    }

    private func run() async {
        isRunning = true
        defer { isRunning = false }
        errorMessage = nil

        var req = Anki_Scheduler_SimulateFsrsReviewRequest()
        req.params = context.weights
        req.desiredRetention = Float(context.desiredRetentionPercent / 100)
        req.deckSize = UInt32(max(0, additionalCards))
        req.daysToSimulate = UInt32(max(1, daysToSimulate))
        req.newLimit = UInt32(max(0, context.newCardsPerDay))
        req.reviewLimit = UInt32(max(0, context.reviewsPerDay))
        req.maxInterval = UInt32(max(1, context.maxIntervalDays))
        req.search = context.search
        req.newCardsIgnoreReviewLimit = context.ignoreNewLimit
        req.historicalRetention = Float(context.historicalRetentionPercent / 100)
        req.learningStepCount = UInt32(context.learningStepCount)
        req.relearningStepCount = UInt32(context.relearningStepCount)
        if context.suspendLeeches {
            req.suspendAfterLapseCount = UInt32(max(1, context.leechThreshold))
        }

        do {
            switch context.mode {
            case .review:
                let response = try deckClient.simulateFsrsReview(req)
                let totalNew = response.dailyNewCount.reduce(0, +)
                let totalReview = response.dailyReviewCount.reduce(0, +)
                let totalTime = response.dailyTimeCost.reduce(0, +)
                let memorized = response.accumulatedKnowledgeAcquisition.last ?? 0
                let days = max(response.dailyReviewCount.count, 1)
                summary = [
                    ("Total new", "\(totalNew)"),
                    ("Total reviews", "\(totalReview)"),
                    ("Avg reviews/day", String(format: "%.1f", Double(totalReview) / Double(days))),
                    ("Total time (s)", String(format: "%.1f", Double(totalTime))),
                    ("Memorized (end)", String(format: "%.1f", Double(memorized)))
                ]
                workloadRows = []
            case .workload:
                let response = try deckClient.simulateFsrsWorkload(req)
                let sorted = response.cost.keys.sorted()
                workloadRows = sorted.map { retention in
                    let cost = response.cost[retention] ?? 0
                    let count = response.reviewCount[retention] ?? 0
                    return (
                        "\(retention)%",
                        String(format: "cost %.2f · reviews %d", Double(cost), count)
                    )
                }
                summary = [("Points", "\(workloadRows.count)")]
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
