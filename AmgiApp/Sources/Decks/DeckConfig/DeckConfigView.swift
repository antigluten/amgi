import SwiftUI
import AmgiTheme
import AnkiKit
import AnkiClients
import Dependencies

/// Per-deck study options. The editable state and all load/save plumbing
/// live in `DeckConfigModel`; this Container binds each form section to
/// `$model.field` and translates engine outcomes into `destination`
/// transitions. Each form section lives in `DeckConfigSections.swift` so
/// SwiftUI can diff the section in isolation and `body` stays readable.
/// Modal presentation (alert + sheet) is driven by a single
/// `DeckConfigDestination?`, applied via the `DeckConfigPresentations`
/// modifier. See the Decks preview-decoupling spec.
struct DeckConfigView: View {
    let deckId: DeckID
    let deckName: String
    let onDismiss: () -> Void

    @State private var model: DeckConfigModel

    @Environment(\.palette) private var palette

    init(deckId: DeckID, deckName: String, onDismiss: @escaping () -> Void) {
        self.deckId = deckId
        self.deckName = deckName
        self.onDismiss = onDismiss
        _model = State(wrappedValue: DeckConfigModel(deckId: deckId, deckName: deckName))
    }

    var body: some View {
        formContent
            .navigationTitle("Deck Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .modifier(DeckConfigPresentations(
                destination: $model.destination,
                currentAlert: model.currentAlert,
                alertTitle: model.alertTitle,
                newPresetName: $model.newPresetName,
                renamePresetDraft: $model.renamePresetDraft,
                deletingPresetName: model.currentPresetName,
                fallbackPresetName: model.deleteFallbackPresetName,
                onCreate: { Task { await model.createPreset() } },
                onRename: { Task { await model.renamePreset() } },
                onDelete: { Task { await model.deletePreset() } },
                onDismissSheet: { model.destination = nil }
            ))
            .task { await model.loadConfig() }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { onDismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Save") { Task { if await model.saveConfig() { onDismiss() } } }
                .disabled(!model.hasLoadedConfig || model.isSaving)
        }
    }

    @ViewBuilder
    private var formContent: some View {
        Form {
            if model.isLoading {
                Section { ProgressView().frame(maxWidth: .infinity) }
            } else if let loadError = model.loadError {
                Section {
                    Text(loadError).foregroundStyle(palette.danger)
                    Button("Retry") { Task { await model.loadConfig() } }
                }
            } else {
                loadedSections
            }
        }
    }

    @ViewBuilder
    private var loadedSections: some View {
        PresetSection(
            presetOptions: model.presetOptions,
            selectedPresetID: model.selectedPresetID,
            selectedPresetName: model.currentPresetName ?? "—",
            presetUseCount: model.presetUseCount,
            canDeletePreset: model.canDeletePreset,
            isPresetMutating: model.isPresetMutating,
            hasLoadedConfig: model.hasLoadedConfig,
            onSelect: { target in Task { await model.selectPreset(target) } },
            onAdd: {
                model.newPresetName = ""
                model.destination = .alert(.createPreset)
            },
            onRename: {
                model.renamePresetDraft = model.currentPresetName ?? ""
                model.destination = .alert(.renamePreset)
            },
            onDelete: { model.destination = .alert(.deletePresetConfirm) }
        )
        DailyLimitsSection(
            newCardsPerDay: $model.newCardsPerDay,
            reviewsPerDay: $model.reviewsPerDay,
            newCardsIgnoreReviewLimit: $model.newCardsIgnoreReviewLimit,
            applyAllParentLimits: $model.applyAllParentLimits
        )
        NewCardsSection(
            learningStepsText: $model.learningStepsText,
            graduatingGoodDays: $model.graduatingGoodDays,
            graduatingEasyDays: $model.graduatingEasyDays
        )
        LapsesSection(
            relearningStepsText: $model.relearningStepsText,
            leechThreshold: $model.leechThreshold,
            leechAction: $model.leechAction
        )
        OrderSection(
            newCardInsertOrder: $model.newCardInsertOrder,
            newCardGatherPriority: $model.newCardGatherPriority,
            newCardSortOrder: $model.newCardSortOrder,
            newMix: $model.newMix,
            reviewOrder: $model.reviewOrder,
            interdayLearningMix: $model.interdayLearningMix
        )
        BurySection(
            buryNew: $model.buryNew,
            buryReviews: $model.buryReviews,
            buryInterdayLearning: $model.buryInterdayLearning
        )
        TimerSection(
            showTimer: $model.showTimer,
            capAnswerTimeToSecs: $model.capAnswerTimeToSecs,
            stopTimerOnAnswer: $model.stopTimerOnAnswer
        )
        AutoAdvanceSection(
            secondsToShowQuestion: $model.secondsToShowQuestion,
            secondsToShowAnswer: $model.secondsToShowAnswer,
            questionAction: $model.questionAction,
            answerAction: $model.answerAction
        )
        AdvancedSection(
            maximumReviewIntervalDays: $model.maximumReviewIntervalDays,
            intervalMultiplierPercent: $model.intervalMultiplierPercent,
            hardMultiplierPercent: $model.hardMultiplierPercent,
            easyMultiplierPercent: $model.easyMultiplierPercent,
            disableAutoplay: $model.disableAutoplay,
            waitForAudio: $model.waitForAudio
        )
        FsrsSection(
            fsrsEnabled: $model.fsrsEnabled,
            desiredRetentionPercent: $model.desiredRetentionPercent,
            historicalRetentionPercent: $model.historicalRetentionPercent,
            fsrsHealthCheck: $model.fsrsHealthCheck,
            fsrsWeightsText: $model.fsrsWeightsText,
            isOptimizingFsrs: model.isOptimizingFsrs,
            onOptimizeCurrent: { Task { await model.optimizeCurrentPreset() } },
            onOpenSimulatorReview: { model.openSimulator(mode: .review) },
            onOpenSimulatorWorkload: { model.openSimulator(mode: .workload) },
            onOptimizeAll: { Task { await model.optimizeAllPresets() } }
        )
        EasyDaysSection(
            fsrsEnabled: model.fsrsEnabled,
            easyDayPercentages: $model.easyDayPercentages
        )
        ApplySection(applyToChildren: $model.applyToChildren)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    let _ = prepareDependencies {
        let config = DeckConfig(
            id: DeckConfigID(1),
            name: "Default",
            config: .init(
                learnSteps: [1, 10],
                relearnSteps: [10],
                newPerDay: 20,
                reviewsPerDay: 200,
                graduatingIntervalGood: 1,
                graduatingIntervalEasy: 4,
                leechThreshold: 8,
                desiredRetention: 0.9,
                historicalRetention: 0.9
            )
        )
        $0.deckClient.getDeckConfig = { _ in config }
        $0.deckClient.fetchDeckConfigContext = { _ in
            DeckConfigsForUpdate(
                allConfig: [DeckConfigsForUpdate.ConfigWithExtra(config: config, useCount: 12)],
                currentDeck: DeckConfigsForUpdate.CurrentDeck(name: "Japanese", configID: config.id),
                defaults: config
            )
        }
    }
    return NavigationStack {
        DeckConfigView(deckId: DeckID(1), deckName: "Japanese", onDismiss: {})
    }
}
#endif
