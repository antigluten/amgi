//
//  FsrsSimulator.swift
//  DecksFeature
//
//  Created by Vladimir Gusev on 14.05.2026.
//

import SwiftUI
import Theme
import AnkiKit

// MARK: - Context

enum FsrsSimulatorMode: String, Identifiable, CaseIterable {
    case review
    case workload
    var id: String { rawValue }
}

struct FsrsSimulatorContext: Identifiable, Hashable {
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

// MARK: - Container

struct FsrsSimulatorView: View {
    @State var context: FsrsSimulatorContext

    @State private var model = FsrsSimulatorModel()
    @State private var daysToSimulate = 365
    @State private var additionalCards = 0

    var body: some View {
        formBody
            .navigationTitle(String(localized: "FSRS Simulator", bundle: .module))
            .navigationBarTitleDisplayMode(.inline)
    }

    private var formBody: some View {
        Form {
            FsrsSimulatorModeSection(mode: $context.mode)
            FsrsSimulatorSettingsSection(
                daysToSimulate: $daysToSimulate,
                additionalCards: $additionalCards,
                mode: context.mode,
                desiredRetentionPercent: $context.desiredRetentionPercent,
                newCardsPerDay: $context.newCardsPerDay,
                reviewsPerDay: $context.reviewsPerDay,
                search: $context.search
            )
            FsrsSimulatorRunSection(
                isRunning: model.isRunning,
                onRun: {
                    Task {
                        await model.run(
                            context: context,
                            daysToSimulate: daysToSimulate,
                            additionalCards: additionalCards
                        )
                    }
                },
                onCancel: { model.cancel() }
            )
            FsrsSimulatorResultsSections(
                summary: model.summary,
                workloadRows: model.workloadRows,
                errorMessage: model.errorMessage
            )
        }
    }

}

// MARK: - Section subviews

struct FsrsSimulatorModeSection: View {
    @Binding var mode: FsrsSimulatorMode

    var body: some View {
        Section {
            Picker(String(localized: "Mode", bundle: .module), selection: $mode) {
                Text("Review", bundle: .module).tag(FsrsSimulatorMode.review)
                Text("Workload", bundle: .module).tag(FsrsSimulatorMode.workload)
            }
            .pickerStyle(.segmented)
        }
    }
}

struct FsrsSimulatorSettingsSection: View {
    @Binding var daysToSimulate: Int
    @Binding var additionalCards: Int
    let mode: FsrsSimulatorMode
    @Binding var desiredRetentionPercent: Double
    @Binding var newCardsPerDay: Int
    @Binding var reviewsPerDay: Int
    @Binding var search: String

    var body: some View {
        Section(String(localized: "Settings", bundle: .module)) {
            Stepper(String(localized: "Days: \(daysToSimulate)", bundle: .module), value: $daysToSimulate, in: 30...3650, step: 30)
            Stepper(String(localized: "Additional cards: \(additionalCards)", bundle: .module), value: $additionalCards, in: 0...100000, step: 100)
            if mode == .review {
                LabeledSlider(
                    label: String(localized: "Desired retention", bundle: .module),
                    value: $desiredRetentionPercent,
                    in: 70...99,
                    step: 1,
                    valueText: "\(Int(desiredRetentionPercent))%"
                )
            }
            Stepper(String(localized: "New/day: \(newCardsPerDay)", bundle: .module), value: $newCardsPerDay, in: 0...9999)
            Stepper(String(localized: "Reviews/day: \(reviewsPerDay)", bundle: .module), value: $reviewsPerDay, in: 0...9999)
            LabeledContent(String(localized: "Search", bundle: .module)) {
                TextField(String(localized: "preset:\"…\" -is:suspended", bundle: .module), text: $search)
                    .multilineTextAlignment(.trailing)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
        }
    }
}

struct FsrsSimulatorRunSection: View {
    let isRunning: Bool
    let onRun: () -> Void
    let onCancel: () -> Void

    var body: some View {
        Section {
            Button(action: onRun) {
                HStack {
                    if isRunning { ProgressView().controlSize(.small) }
                    Text(isRunning ? "Running…" : "Run Simulation", bundle: .module)
                }
            }
            .disabled(isRunning)
            if isRunning {
                Button(String(localized: "Cancel", bundle: .module), role: .cancel, action: onCancel)
            }
        }
    }
}

struct FsrsSimulatorResultsSections: View {
    let summary: [(label: String, value: String)]
    let workloadRows: [(label: String, value: String)]
    let errorMessage: String?

    @Environment(\.palette) private var palette

    var body: some View {
        if !summary.isEmpty {
            Section(String(localized: "Summary", bundle: .module)) {
                ForEach(summary, id: \.label) { item in
                    LabeledContent(item.label, value: item.value)
                }
            }
        }
        if !workloadRows.isEmpty {
            Section(String(localized: "Retention vs cost", bundle: .module)) {
                ForEach(workloadRows, id: \.label) { row in
                    LabeledContent(row.label, value: row.value)
                }
            }
        }
        if let errorMessage {
            Section {
                Text(errorMessage).foregroundStyle(palette.danger)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    NavigationStack {
        FsrsSimulatorView(
            context: .preview
        )
    }
}

private extension FsrsSimulatorContext {
    static let preview = FsrsSimulatorContext(
        mode: .review,
        weights: [0.4, 0.6, 2.4, 5.8],
        desiredRetentionPercent: 90,
        historicalRetentionPercent: 90,
        newCardsPerDay: 20,
        reviewsPerDay: 200,
        maxIntervalDays: 36500,
        search: "preset:\"Default\" -is:suspended",
        ignoreNewLimit: false,
        suspendLeeches: true,
        leechThreshold: 8,
        learningStepCount: 2,
        relearningStepCount: 1
    )
}
#endif
