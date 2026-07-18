import SwiftUI
import AmgiTheme
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
        Section("Preset") {
            LabeledContent("Preset") {
                Menu {
                    Picker("Preset", selection: Binding(
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

            LabeledContent("Used by") {
                Text("\(presetUseCount) deck\(presetUseCount == 1 ? "" : "s")")
                    .foregroundStyle(palette.textSecondary)
            }

            Menu {
                Button { onAdd() } label: {
                    Label("Add preset…", systemImage: "plus")
                }
                Button { onRename() } label: {
                    Label("Rename…", systemImage: "pencil")
                }
                .disabled(!hasLoadedConfig)
                Button(role: .destructive) { onDelete() } label: {
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
}

struct DailyLimitsSection: View {
    @Binding var newCardsPerDay: Int32
    @Binding var reviewsPerDay: Int32
    @Binding var newCardsIgnoreReviewLimit: Bool
    @Binding var applyAllParentLimits: Bool

    var body: some View {
        Section("Daily Limits") {
            Stepper("New cards/day: \(newCardsPerDay)", value: $newCardsPerDay, in: 0...9999)
            Stepper("Reviews/day: \(reviewsPerDay)", value: $reviewsPerDay, in: 0...9999)
            Toggle("New cards ignore review limit", isOn: $newCardsIgnoreReviewLimit)
            Toggle("Apply all parent limits", isOn: $applyAllParentLimits)
        }
    }
}

struct NewCardsSection: View {
    @Binding var learningStepsText: String
    @Binding var graduatingGoodDays: Int32
    @Binding var graduatingEasyDays: Int32

    var body: some View {
        Section("New Cards") {
            LabeledContent("Learning steps") {
                TextField("1m 10m", text: $learningStepsText)
                    .multilineTextAlignment(.trailing)
                    .font(.system(size: AmgiFont.body.size, weight: AmgiFont.body.weight, design: .monospaced))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
            Stepper("Graduating interval: \(graduatingGoodDays)d", value: $graduatingGoodDays, in: 0...365)
            Stepper("Easy interval: \(graduatingEasyDays)d", value: $graduatingEasyDays, in: 0...365)
        }
    }
}

struct LapsesSection: View {
    @Binding var relearningStepsText: String
    @Binding var leechThreshold: Int32
    @Binding var leechAction: LeechAction

    var body: some View {
        Section("Lapses") {
            LabeledContent("Relearning steps") {
                TextField("10m", text: $relearningStepsText)
                    .multilineTextAlignment(.trailing)
                    .font(.system(size: AmgiFont.body.size, weight: AmgiFont.body.weight, design: .monospaced))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
            Stepper("Leech threshold: \(leechThreshold)", value: $leechThreshold, in: 1...9999)
            Picker("Leech action", selection: $leechAction) {
                Text("Suspend card").tag(LeechAction.suspend)
                Text("Tag only").tag(LeechAction.tagOnly)
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
        Section("Order") {
            Picker("New card insert order", selection: $newCardInsertOrder) {
                Text("Sequential (oldest first)").tag(NewCardInsertOrder.due)
                Text("Random").tag(NewCardInsertOrder.random)
            }
            Picker("New gather priority", selection: $newCardGatherPriority) {
                Text("Deck").tag(NewCardGatherPriority.deck)
                Text("Deck, then random notes").tag(NewCardGatherPriority.deckThenRandomNotes)
                Text("Position — lowest first").tag(NewCardGatherPriority.lowestPosition)
                Text("Position — highest first").tag(NewCardGatherPriority.highestPosition)
                Text("Random notes").tag(NewCardGatherPriority.randomNotes)
                Text("Random cards").tag(NewCardGatherPriority.randomCards)
            }
            Picker("New card sort order", selection: $newCardSortOrder) {
                Text("Card template, then gather order").tag(NewCardSortOrder.template)
                Text("Gather order").tag(NewCardSortOrder.noSort)
                Text("Card template, then random").tag(NewCardSortOrder.templateThenRandom)
                Text("Random note, then template").tag(NewCardSortOrder.randomNoteThenTemplate)
                Text("Random").tag(NewCardSortOrder.randomCard)
            }
            Picker("New/review mix", selection: $newMix) {
                Text("Mix with reviews").tag(ReviewMix.mixWithReviews)
                Text("After reviews").tag(ReviewMix.afterReviews)
                Text("Before reviews").tag(ReviewMix.beforeReviews)
            }
            Picker("Review order", selection: $reviewOrder) {
                Text("Mixed by day").tag(ReviewCardOrder.day)
                Text("Day, then deck").tag(ReviewCardOrder.dayThenDeck)
                Text("Deck, then day").tag(ReviewCardOrder.deckThenDay)
                Text("Intervals — ascending").tag(ReviewCardOrder.intervalsAscending)
                Text("Intervals — descending").tag(ReviewCardOrder.intervalsDescending)
                Text("Retrievability — descending").tag(ReviewCardOrder.retrievabilityDescending)
                Text("Random").tag(ReviewCardOrder.random)
            }
            Picker("Interday learning mix", selection: $interdayLearningMix) {
                Text("Mix with reviews").tag(ReviewMix.mixWithReviews)
                Text("After reviews").tag(ReviewMix.afterReviews)
                Text("Before reviews").tag(ReviewMix.beforeReviews)
            }
        }
    }
}

struct BurySection: View {
    @Binding var buryNew: Bool
    @Binding var buryReviews: Bool
    @Binding var buryInterdayLearning: Bool

    var body: some View {
        Section("Bury siblings") {
            Toggle("Bury new siblings", isOn: $buryNew)
            Toggle("Bury review siblings", isOn: $buryReviews)
            Toggle("Bury interday-learning siblings", isOn: $buryInterdayLearning)
        }
    }
}

struct TimerSection: View {
    @Binding var showTimer: Bool
    @Binding var capAnswerTimeToSecs: Int32
    @Binding var stopTimerOnAnswer: Bool

    var body: some View {
        Section("Answer timer") {
            Toggle("Show answer timer", isOn: $showTimer)
            Stepper("Max answer seconds: \(capAnswerTimeToSecs)", value: $capAnswerTimeToSecs, in: 5...600, step: 5)
            Toggle("Stop timer on answer", isOn: $stopTimerOnAnswer)
        }
    }
}

struct AutoAdvanceSection: View {
    @Binding var secondsToShowQuestion: Double
    @Binding var secondsToShowAnswer: Double
    @Binding var questionAction: QuestionAction
    @Binding var answerAction: AnswerAction

    var body: some View {
        Section("Auto-advance") {
            LabeledSlider(
                label: "Seconds to show question",
                value: $secondsToShowQuestion,
                in: 0...60,
                step: 0.5,
                valueText: String(format: "%.1f s", secondsToShowQuestion)
            )
            LabeledSlider(
                label: "Seconds to show answer",
                value: $secondsToShowAnswer,
                in: 0...60,
                step: 0.5,
                valueText: String(format: "%.1f s", secondsToShowAnswer)
            )
            Picker("After question", selection: $questionAction) {
                Text("Show answer").tag(QuestionAction.showAnswer)
                Text("Show reminder").tag(QuestionAction.showReminder)
            }
            Picker("After answer", selection: $answerAction) {
                Text("Bury card").tag(AnswerAction.buryCard)
                Text("Answer Again").tag(AnswerAction.answerAgain)
                Text("Answer Hard").tag(AnswerAction.answerHard)
                Text("Answer Good").tag(AnswerAction.answerGood)
                Text("Show reminder").tag(AnswerAction.showReminder)
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
        Section("Advanced (SM-2)") {
            Stepper("Maximum review interval: \(maximumReviewIntervalDays)d", value: $maximumReviewIntervalDays, in: 1...36500, step: 30)
            LabeledSlider(
                label: "Interval multiplier",
                value: $intervalMultiplierPercent,
                in: 50...200,
                step: 1,
                valueText: "\(Int(intervalMultiplierPercent))%"
            )
            LabeledSlider(
                label: "Hard multiplier",
                value: $hardMultiplierPercent,
                in: 80...200,
                step: 1,
                valueText: "\(Int(hardMultiplierPercent))%"
            )
            LabeledSlider(
                label: "Easy multiplier",
                value: $easyMultiplierPercent,
                in: 100...300,
                step: 1,
                valueText: "\(Int(easyMultiplierPercent))%"
            )
            Toggle("Disable autoplay audio", isOn: $disableAutoplay)
            Toggle("Wait for audio before answering", isOn: $waitForAudio)
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
    let onOpenSimulatorReview: () -> Void
    let onOpenSimulatorWorkload: () -> Void
    let onOptimizeAll: () -> Void

    var body: some View {
        Section("FSRS") {
            Toggle("Enable FSRS", isOn: $fsrsEnabled)
            LabeledSlider(
                label: "Desired retention",
                value: $desiredRetentionPercent,
                in: 70...97,
                step: 1,
                valueText: "\(Int(desiredRetentionPercent))%"
            )
            LabeledSlider(
                label: "Historical retention",
                value: $historicalRetentionPercent,
                in: 70...100,
                step: 1,
                valueText: "\(Int(historicalRetentionPercent))%"
            )
            Toggle("Run FSRS health check on save", isOn: $fsrsHealthCheck)

            if fsrsEnabled {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Weights").amgiFont(.body)
                    TextField(
                        "Space- or comma-separated parameters",
                        text: $fsrsWeightsText,
                        axis: .vertical
                    )
                    .lineLimit(2...6)
                    .font(.system(size: AmgiFont.caption.size, weight: AmgiFont.caption.weight, design: .monospaced))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                }

                Button(action: onOptimizeCurrent) {
                    HStack {
                        if isOptimizingFsrs { ProgressView().controlSize(.small) }
                        Text(isOptimizingFsrs ? "Optimizing…" : "Optimize Weights")
                    }
                }
                .disabled(isOptimizingFsrs)

                Button(action: onOpenSimulatorReview) {
                    Label("Open FSRS Simulator", systemImage: "chart.line.uptrend.xyaxis")
                }
                .disabled(isOptimizingFsrs)

                Button(action: onOpenSimulatorWorkload) {
                    Label("Help Me Decide (Workload)", systemImage: "scale.3d")
                }
                .disabled(isOptimizingFsrs)

                Button(action: onOptimizeAll) {
                    HStack {
                        if isOptimizingFsrs { ProgressView().controlSize(.small) }
                        Text("Optimize All Presets")
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
                Text("Enable FSRS to configure Easy Days.")
                    .foregroundStyle(palette.textSecondary)
            }
        } header: {
            Text("Easy Days")
        } footer: {
            Text("Reduce the daily workload on specific weekdays. 100% means a normal day; lower values back off reviews on that day.")
        }
    }
}

struct ApplySection: View {
    @Binding var applyToChildren: Bool

    var body: some View {
        Section {
            Toggle("Apply to subdecks", isOn: $applyToChildren)
        } footer: {
            Text("Settings will be applied to this deck and any nested subdecks that share its preset.")
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
                Spacer()
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
        ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"][idx]
    }
}
