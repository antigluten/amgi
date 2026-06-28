import SwiftUI
import AnkiKit

// MARK: - Context

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

// MARK: - Container

struct FsrsSimulatorView: View {
    @State var context: FsrsSimulatorContext
    let onDismiss: () -> Void

    @State private var model = FsrsSimulatorModel()
    @State private var daysToSimulate = 365
    @State private var additionalCards = 0

    var body: some View {
        NavigationStack {
            formBody
                .navigationTitle("FSRS Simulator")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbarContent }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            Button("Done") { onDismiss() }
        }
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
                }
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
            Picker("Mode", selection: $mode) {
                Text("Review").tag(FsrsSimulatorMode.review)
                Text("Workload").tag(FsrsSimulatorMode.workload)
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
        Section("Settings") {
            Stepper("Days: \(daysToSimulate)", value: $daysToSimulate, in: 30...3650, step: 30)
            Stepper("Additional cards: \(additionalCards)", value: $additionalCards, in: 0...100000, step: 100)
            if mode == .review {
                LabeledSlider(
                    label: "Desired retention",
                    value: $desiredRetentionPercent,
                    in: 70...99,
                    step: 1,
                    valueText: "\(Int(desiredRetentionPercent))%"
                )
            }
            Stepper("New/day: \(newCardsPerDay)", value: $newCardsPerDay, in: 0...9999)
            Stepper("Reviews/day: \(reviewsPerDay)", value: $reviewsPerDay, in: 0...9999)
            LabeledContent("Search") {
                TextField("preset:\"…\" -is:suspended", text: $search)
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

    var body: some View {
        Section {
            Button(action: onRun) {
                HStack {
                    if isRunning { ProgressView().controlSize(.small) }
                    Text(isRunning ? "Running…" : "Run Simulation")
                }
            }
            .disabled(isRunning)
        }
    }
}

struct FsrsSimulatorResultsSections: View {
    let summary: [(label: String, value: String)]
    let workloadRows: [(label: String, value: String)]
    let errorMessage: String?

    var body: some View {
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
}

// MARK: - Preview

#if DEBUG
#Preview {
    FsrsSimulatorView(
        context: FsrsSimulatorContext(
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
        ),
        onDismiss: {}
    )
}
#endif
