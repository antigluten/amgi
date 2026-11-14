//
//  DeckConfigSections.swift
//  DecksFeature
//
//  Created by Vladimir Gusev on 14.05.2026.
//

import SwiftUI
import Theme
import AnkiKit

// Section structs for the deck-options Form. Each is dedicated so SwiftUI can
// skip its body when its inputs don't change — e.g. tapping a Stepper in
// Daily Limits doesn't force the FSRS Weights TextField to re-evaluate.
// Bindings are scoped to exactly the @State each section reads/writes;
// everything else is `let`.

struct PresetSection: View {
    let presetOptions: [DeckConfigsForUpdate.ConfigWithExtra]
    let selectedPresetID: DeckConfigID
    let selectedPresetName: String
    let presetUseCount: Int
    let canDeletePreset: Bool
    let isPresetMutating: Bool
    let hasLoadedConfig: Bool
    let onSelect: (DeckConfig) -> Void
    let onAdd: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        Section(String(localized: "Preset", bundle: .module)) {
            LabeledContent(String(localized: "Preset", bundle: .module)) {
                Menu {
                    Picker(String(localized: "Preset", bundle: .module), selection: Binding(
                        get: { selectedPresetID },
                        set: { newID in
                            guard newID != selectedPresetID,
                                  let target = presetOptions.first(where: { $0.config.id == newID })?.config
                            else { return }
                            onSelect(target)
                        }
                    )) {
                        ForEach(presetOptions, id: \.config.id) { option in
                            Text(option.config.name).tag(option.config.id)
                        }
                    }
                } label: {
                    HStack {
                        Text(selectedPresetName).foregroundStyle(palette.textPrimary)
                        Image(systemName: "chevron.up.chevron.down")
                            .amgiFont(.micro)
                            .foregroundStyle(palette.textSecondary)
                    }
                }
                .disabled(isPresetMutating || presetOptions.isEmpty)
            }

            LabeledContent(String(localized: "Used by", bundle: .module)) {
                Text("\(presetUseCount) decks", bundle: .module)
                    .foregroundStyle(palette.textSecondary)
            }

            Menu {
                Button { onAdd() } label: {
                    Label(String(localized: "Add Preset…", bundle: .module), systemImage: "plus")
                }
                Button { onRename() } label: {
                    Label(String(localized: "Rename Preset…", bundle: .module), systemImage: "pencil")
                }
                .disabled(!hasLoadedConfig)
                Button(role: .destructive) { onDelete() } label: {
                    Label(String(localized: "Delete Preset", bundle: .module), systemImage: "trash")
                }
                .disabled(!canDeletePreset)
            } label: {
                if isPresetMutating {
                    HStack { ProgressView().controlSize(.small); Text("Working…", bundle: .module) }
                } else {
                    Label(String(localized: "Manage Preset", bundle: .module), systemImage: "slider.horizontal.below.rectangle")
                }
            }
            .disabled(isPresetMutating)
        }
    }
}

struct DailyLimitsSection: View {
    @Binding var newCardsPerDay: Int32
    @Binding var reviewsPerDay: Int32
    @Binding var newCardsIgnoreReviewLimit: Bool
    @Binding var applyAllParentLimits: Bool

    var body: some View {
        Section(String(localized: "Daily Limits", bundle: .module)) {
            Stepper(String(localized: "New cards/day: \(newCardsPerDay)", bundle: .module), value: $newCardsPerDay, in: 0...9999)
            Stepper(String(localized: "Reviews/day: \(reviewsPerDay)", bundle: .module), value: $reviewsPerDay, in: 0...9999)
            Toggle(String(localized: "New cards ignore review limit", bundle: .module), isOn: $newCardsIgnoreReviewLimit)
            Toggle(String(localized: "Apply all parent limits", bundle: .module), isOn: $applyAllParentLimits)
        }
    }
}

struct NewCardsSection: View {
    @Binding var learningStepsText: String
    @Binding var graduatingGoodDays: Int32
    @Binding var graduatingEasyDays: Int32

    var body: some View {
        Section(String(localized: "New Cards", bundle: .module)) {
            LabeledContent(String(localized: "Learning steps", bundle: .module)) {
                TextField("1m 10m", text: $learningStepsText)
                    .multilineTextAlignment(.trailing)
                    .amgiFont(.body, .monospaced)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
            Stepper(String(localized: "Graduating interval: \(graduatingGoodDays)d", bundle: .module), value: $graduatingGoodDays, in: 0...365)
            Stepper(String(localized: "Easy interval: \(graduatingEasyDays)d", bundle: .module), value: $graduatingEasyDays, in: 0...365)
        }
    }
}

struct LapsesSection: View {
    @Binding var relearningStepsText: String
    @Binding var leechThreshold: Int32
    @Binding var leechAction: LeechAction

    var body: some View {
        Section(String(localized: "Lapses", bundle: .module)) {
            LabeledContent(String(localized: "Relearning steps", bundle: .module)) {
                TextField("10m", text: $relearningStepsText)
                    .multilineTextAlignment(.trailing)
                    .amgiFont(.body, .monospaced)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
            Stepper(String(localized: "Leech threshold: \(leechThreshold)", bundle: .module), value: $leechThreshold, in: 1...9999)
            Picker(String(localized: "Leech action", bundle: .module), selection: $leechAction) {
                Text("Suspend card", bundle: .module).tag(LeechAction.suspend)
                Text("Tag only", bundle: .module).tag(LeechAction.tagOnly)
            }
        }
    }
}

struct OrderSection: View {
    @Binding var newCardInsertOrder: NewCardInsertOrder
    @Binding var newCardGatherPriority: NewCardGatherPriority
    @Binding var newCardSortOrder: NewCardSortOrder
    @Binding var newMix: ReviewMix
    @Binding var reviewOrder: ReviewCardOrder
    @Binding var interdayLearningMix: ReviewMix

    var body: some View {
        Section(String(localized: "Order", bundle: .module)) {
            Picker(String(localized: "New card insert order", bundle: .module), selection: $newCardInsertOrder) {
                Text("Sequential (oldest first)", bundle: .module).tag(NewCardInsertOrder.due)
                Text("Random", bundle: .module).tag(NewCardInsertOrder.random)
            }
            Picker(String(localized: "New gather priority", bundle: .module), selection: $newCardGatherPriority) {
                Text("Deck", bundle: .module).tag(NewCardGatherPriority.deck)
                Text("Deck, then random notes", bundle: .module).tag(NewCardGatherPriority.deckThenRandomNotes)
                Text("Position — lowest first", bundle: .module).tag(NewCardGatherPriority.lowestPosition)
                Text("Position — highest first", bundle: .module).tag(NewCardGatherPriority.highestPosition)
                Text("Random notes", bundle: .module).tag(NewCardGatherPriority.randomNotes)
                Text("Random cards", bundle: .module).tag(NewCardGatherPriority.randomCards)
            }
            Picker(String(localized: "New card sort order", bundle: .module), selection: $newCardSortOrder) {
                Text("Card template, then gather order", bundle: .module).tag(NewCardSortOrder.template)
                Text("Gather order", bundle: .module).tag(NewCardSortOrder.noSort)
                Text("Card template, then random", bundle: .module).tag(NewCardSortOrder.templateThenRandom)
                Text("Random note, then template", bundle: .module).tag(NewCardSortOrder.randomNoteThenTemplate)
                Text("Random", bundle: .module).tag(NewCardSortOrder.randomCard)
            }
            Picker(String(localized: "New/review mix", bundle: .module), selection: $newMix) {
                Text("Mix with reviews", bundle: .module).tag(ReviewMix.mixWithReviews)
                Text("After reviews", bundle: .module).tag(ReviewMix.afterReviews)
                Text("Before reviews", bundle: .module).tag(ReviewMix.beforeReviews)
            }
            Picker(String(localized: "Review order", bundle: .module), selection: $reviewOrder) {
                Text("Mixed by day", bundle: .module).tag(ReviewCardOrder.day)
                Text("Day, then deck", bundle: .module).tag(ReviewCardOrder.dayThenDeck)
                Text("Deck, then day", bundle: .module).tag(ReviewCardOrder.deckThenDay)
                Text("Intervals — ascending", bundle: .module).tag(ReviewCardOrder.intervalsAscending)
                Text("Intervals — descending", bundle: .module).tag(ReviewCardOrder.intervalsDescending)
                Text("Retrievability — descending", bundle: .module).tag(ReviewCardOrder.retrievabilityDescending)
                Text("Random", bundle: .module).tag(ReviewCardOrder.random)
            }
            Picker(String(localized: "Interday learning mix", bundle: .module), selection: $interdayLearningMix) {
                Text("Mix with reviews", bundle: .module).tag(ReviewMix.mixWithReviews)
                Text("After reviews", bundle: .module).tag(ReviewMix.afterReviews)
                Text("Before reviews", bundle: .module).tag(ReviewMix.beforeReviews)
            }
        }
    }
}

struct BurySection: View {
    @Binding var buryNew: Bool
    @Binding var buryReviews: Bool
    @Binding var buryInterdayLearning: Bool

    var body: some View {
        Section(String(localized: "Bury siblings", bundle: .module)) {
            Toggle(String(localized: "Bury new siblings", bundle: .module), isOn: $buryNew)
            Toggle(String(localized: "Bury review siblings", bundle: .module), isOn: $buryReviews)
            Toggle(String(localized: "Bury interday-learning siblings", bundle: .module), isOn: $buryInterdayLearning)
        }
    }
}

struct TimerSection: View {
    @Binding var showTimer: Bool
    @Binding var capAnswerTimeToSecs: Int32
    @Binding var stopTimerOnAnswer: Bool

    var body: some View {
        Section(String(localized: "Answer timer", bundle: .module)) {
            Toggle(String(localized: "Show answer timer", bundle: .module), isOn: $showTimer)
            Stepper(String(localized: "Max answer seconds: \(capAnswerTimeToSecs)", bundle: .module), value: $capAnswerTimeToSecs, in: 5...600, step: 5)
            Toggle(String(localized: "Stop timer on answer", bundle: .module), isOn: $stopTimerOnAnswer)
        }
    }
}

struct AutoAdvanceSection: View {
    @Binding var secondsToShowQuestion: Double
    @Binding var secondsToShowAnswer: Double
    @Binding var questionAction: QuestionAction
    @Binding var answerAction: AnswerAction

    var body: some View {
        Section(String(localized: "Auto-advance", bundle: .module)) {
            LabeledSlider(
                label: String(localized: "Seconds to show question", bundle: .module),
                value: $secondsToShowQuestion,
                in: 0...60,
                step: 0.5,
                valueText: String(format: "%.1f s", secondsToShowQuestion)
            )
            LabeledSlider(
                label: String(localized: "Seconds to show answer", bundle: .module),
                value: $secondsToShowAnswer,
                in: 0...60,
                step: 0.5,
                valueText: String(format: "%.1f s", secondsToShowAnswer)
            )
            Picker(String(localized: "After question", bundle: .module), selection: $questionAction) {
                Text("Show answer", bundle: .module).tag(QuestionAction.showAnswer)
                Text("Show reminder", bundle: .module).tag(QuestionAction.showReminder)
            }
            Picker(String(localized: "After answer", bundle: .module), selection: $answerAction) {
                Text("Bury card", bundle: .module).tag(AnswerAction.buryCard)
                Text("Answer Again", bundle: .module).tag(AnswerAction.answerAgain)
                Text("Answer Hard", bundle: .module).tag(AnswerAction.answerHard)
                Text("Answer Good", bundle: .module).tag(AnswerAction.answerGood)
                Text("Show reminder", bundle: .module).tag(AnswerAction.showReminder)
            }
        }
    }
}

struct AdvancedSection: View {
    @Binding var maximumReviewIntervalDays: Int32
    @Binding var intervalMultiplierPercent: Double
    @Binding var hardMultiplierPercent: Double
    @Binding var easyMultiplierPercent: Double
    @Binding var disableAutoplay: Bool
    @Binding var waitForAudio: Bool

    var body: some View {
        Section(String(localized: "Advanced (SM-2)", bundle: .module)) {
            Stepper(String(localized: "Maximum review interval: \(maximumReviewIntervalDays)d", bundle: .module), value: $maximumReviewIntervalDays, in: 1...36500, step: 30)
            LabeledSlider(
                label: String(localized: "Interval multiplier", bundle: .module),
                value: $intervalMultiplierPercent,
                in: 50...200,
                step: 1,
                valueText: "\(Int(intervalMultiplierPercent))%"
            )
            LabeledSlider(
                label: String(localized: "Hard multiplier", bundle: .module),
                value: $hardMultiplierPercent,
                in: 80...200,
                step: 1,
                valueText: "\(Int(hardMultiplierPercent))%"
            )
            LabeledSlider(
                label: String(localized: "Easy multiplier", bundle: .module),
                value: $easyMultiplierPercent,
                in: 100...300,
                step: 1,
                valueText: "\(Int(easyMultiplierPercent))%"
            )
            Toggle(String(localized: "Disable autoplay audio", bundle: .module), isOn: $disableAutoplay)
            Toggle(String(localized: "Wait for audio before answering", bundle: .module), isOn: $waitForAudio)
        }
    }
}

struct FsrsSection: View {
    @Binding var fsrsEnabled: Bool
    @Binding var desiredRetentionPercent: Double
    @Binding var historicalRetentionPercent: Double
    @Binding var fsrsHealthCheck: Bool
    @Binding var fsrsWeightsText: String
    let isOptimizingFsrs: Bool
    let onOptimizeCurrent: () -> Void
    let onCancelOptimize: () -> Void
    let onOpenSimulatorReview: () -> Void
    let onOpenSimulatorWorkload: () -> Void
    let onOptimizeAll: () -> Void

    var body: some View {
        Section(String(localized: "FSRS", bundle: .module)) {
            Toggle(String(localized: "Enable FSRS", bundle: .module), isOn: $fsrsEnabled)
            LabeledSlider(
                label: String(localized: "Desired retention", bundle: .module),
                value: $desiredRetentionPercent,
                in: 70...97,
                step: 1,
                valueText: "\(Int(desiredRetentionPercent))%"
            )
            LabeledSlider(
                label: String(localized: "Historical retention", bundle: .module),
                value: $historicalRetentionPercent,
                in: 70...100,
                step: 1,
                valueText: "\(Int(historicalRetentionPercent))%"
            )
            Toggle(String(localized: "Run FSRS health check on save", bundle: .module), isOn: $fsrsHealthCheck)

            if fsrsEnabled {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Weights", bundle: .module).amgiFont(.body)
                    TextField(
                        String(localized: "Space- or comma-separated parameters", bundle: .module),
                        text: $fsrsWeightsText,
                        axis: .vertical
                    )
                    .lineLimit(2...6)
                    .amgiFont(.caption, .monospaced)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                }

                Button(action: onOptimizeCurrent) {
                    HStack {
                        if isOptimizingFsrs { ProgressView().controlSize(.small) }
                        Text(isOptimizingFsrs ? "Optimizing…" : "Optimize Weights", bundle: .module)
                    }
                }
                .disabled(isOptimizingFsrs)

                if isOptimizingFsrs {
                    Button(String(localized: "Cancel", bundle: .module), role: .cancel, action: onCancelOptimize)
                }

                Button(action: onOpenSimulatorReview) {
                    Label(String(localized: "Open FSRS Simulator", bundle: .module), systemImage: "chart.line.uptrend.xyaxis")
                }
                .disabled(isOptimizingFsrs)

                Button(action: onOpenSimulatorWorkload) {
                    Label(String(localized: "Help Me Decide (Workload)", bundle: .module), systemImage: "scale.3d")
                }
                .disabled(isOptimizingFsrs)

                Button(action: onOptimizeAll) {
                    HStack {
                        if isOptimizingFsrs { ProgressView().controlSize(.small) }
                        Text("Optimize All Presets", bundle: .module)
                    }
                }
                .disabled(isOptimizingFsrs)
            }
        }
    }
}

struct EasyDaysSection: View {
    let fsrsEnabled: Bool
    @Binding var easyDayPercentages: [Double]

    @Environment(\.palette) private var palette

    var body: some View {
        // FSRS interprets these as per-weekday workload multipliers; only
        // shown when FSRS is enabled, matching Anki desktop's gating.
        Section {
            if fsrsEnabled {
                ForEach(0..<7, id: \.self) { idx in
                    LabeledSlider(
                        label: Self.weekdayLabel(idx),
                        value: $easyDayPercentages[idx],
                        in: 50...150,
                        step: 5,
                        valueText: "\(Int(easyDayPercentages[idx]))%"
                    )
                }
            } else {
                Text("Enable FSRS to configure Easy Days.", bundle: .module)
                    .foregroundStyle(palette.textSecondary)
            }
        } header: {
            Text("Easy Days", bundle: .module)
        } footer: {
            Text("Reduce the daily workload on specific weekdays. 100% means a normal day; lower values back off reviews on that day.", bundle: .module)
        }
    }
}

struct ApplySection: View {
    @Binding var applyToChildren: Bool

    var body: some View {
        Section {
            Toggle(String(localized: "Apply to subdecks", bundle: .module), isOn: $applyToChildren)
        } footer: {
            Text("Settings will be applied to this deck and any nested subdecks that share its preset.", bundle: .module)
        }
    }
}

/// Reused across sections: "<label> ...... <valueText>" with a slider below.
struct LabeledSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let valueText: String

    @Environment(\.palette) private var palette

    init(label: String, value: Binding<Double>, in range: ClosedRange<Double>, step: Double, valueText: String) {
        self.label = label
        self._value = value
        self.range = range
        self.step = step
        self.valueText = valueText
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(valueText).foregroundStyle(palette.textSecondary)
            }
            Slider(value: $value, in: range, step: step)
        }
    }
}

private extension EasyDaysSection {
    /// Anki stores easyDaysPercentages indexed Mon=0..Sun=6. Use fixed
    /// short labels rather than `Calendar.shortWeekdaySymbols` so the UI
    /// order matches the underlying storage regardless of locale.
    static func weekdayLabel(_ idx: Int) -> String {
        [String(localized: "Monday", bundle: .module), String(localized: "Tuesday", bundle: .module), String(localized: "Wednesday", bundle: .module), String(localized: "Thursday", bundle: .module), String(localized: "Friday", bundle: .module), String(localized: "Saturday", bundle: .module), String(localized: "Sunday", bundle: .module)][idx]
    }
}
