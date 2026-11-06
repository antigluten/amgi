import AppCore
import Foundation
package import SwiftUI
import Theme
import UIKit
import AppShared
import AnkiKit

package struct WordSpotlightSettingsView: View {
    package init() {}

    @Environment(\.palette) private var palette
    @Environment(\.scenePhase) private var scenePhase
    @State private var model = WordSpotlightSettingsModel()

    package var body: some View {
        Form {
            currentWordSection
            errorSection
            sourceSection
            rotationSection
            notificationsSection

            if model.isSaving {
                Section { ProgressView("Saving…") }
            }
            if model.savedPreferences.isConfigured {
                Section {
                    Button("Turn Off Word Spotlight", role: .destructive) {
                        Task { await model.disable() }
                    }
                }
            }
            Section {
                Text("Home Screen: touch and hold → Edit → Add Widget → Amgi → Word Spotlight.")
                Text("Lock Screen: touch and hold → Customize → Lock Screen → Add Widgets → Amgi.")
            }
            .foregroundStyle(palette.textSecondary)
        }
        .disabled(model.isLoading || model.isSaving || model.isAdvancing)
        .scrollContentBackground(.hidden)
        .background(palette.background)
        .navigationTitle("Word Spotlight")
        .task { await model.load() }
        .task(id: model.preferences.notetypeID) { await model.loadFields() }
        .task(id: "\(model.preferences.sourceID)-\(model.isLoading)") { await model.loadPreview() }
        .onChange(of: model.preferences.sourceID) { _, _ in model.sourceStatus = nil }
        .onChange(of: model.optionValues(model.preferences)) { _, options in
            guard !model.isLoading, !model.isSaving, model.savedPreferences.isConfigured,
                  options != model.optionValues(model.savedPreferences) else { return }
            Task { await model.saveOptions() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await model.controller.refresh() } }
        }
    }

    @ViewBuilder private var currentWordSection: some View {
        if model.savedPreferences.isConfigured {
            Section("Current word") {
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    if let word = model.controller.schedule?.word(on: context.date) {
                        wordContent(word)
                    } else {
                        Text("No word is available. Refresh or check your vocabulary source.")
                            .foregroundStyle(palette.textSecondary)
                    }
                }
                Button {
                    Task { await model.advance() }
                } label: {
                    HStack {
                        Label("Next word", systemImage: "arrow.forward")
                        Spacer()
                        if model.isAdvancing { ProgressView() }
                    }
                }
                .disabled(!model.controller.canAdvance || model.isAdvancing)
                if model.controller.wordCount == 1 {
                    Text("Only one eligible word. Add more vocabulary cards to see another.")
                        .foregroundStyle(palette.textSecondary)
                }
            }
        }
    }

    @ViewBuilder private var errorSection: some View {
        if let error = model.error ?? model.controller.error {
            Section {
                Text(error).foregroundStyle(palette.danger)
                Button("Retry") { Task { await model.retry() } }
            }
        }
    }

    private var sourceSection: some View {
        Section {
            Picker("Vocabulary deck", selection: $model.preferences.deckID) {
                Text("Choose a deck").tag(Int64(0))
                ForEach(model.decks) { Text($0.name).tag($0.id.rawValue) }
            }
            .accessibilityIdentifier("wordSpotlight.deck")
            Picker("Note type", selection: $model.preferences.notetypeID) {
                Text("Choose a note type").tag(Int64(0))
                ForEach(model.notetypes) { Text($0.name).tag($0.id.rawValue) }
            }
            fieldPicker("Word", selection: $model.preferences.termField)
            fieldPicker("Meaning", selection: $model.preferences.meaningField)
            fieldPicker("Reading (optional)", selection: $model.preferences.readingField)

            if model.needsSourceSave { sourcePreview }

            Button(model.savedPreferences.isConfigured ? "Save source" : "Enable Word Spotlight") {
                Task { await model.saveSource() }
            }
            .disabled(!model.canSaveSource)
            .accessibilityIdentifier("wordSpotlight.saveSource")
            if let sourceStatus = model.sourceStatus, !model.needsSourceSave {
                Text(sourceStatus).foregroundStyle(palette.textSecondary)
            }
        } header: {
            Text("Your vocabulary")
        } footer: {
            Text("Uses up to 500 notes. Suspended, buried, cloze and media-only entries are skipped. Viewing a word does not grade its card.")
        }
    }

    @ViewBuilder private var sourcePreview: some View {
        switch model.preview {
        case .loading:
            ProgressView("Loading preview…")
        case .ready(_, let words) where !words.isEmpty:
            if let word = words.first { wordContent(word) }
            Text("\(words.count) eligible words. Confirm that the word and meaning look right.")
                .amgiFont(.caption).foregroundStyle(palette.textSecondary)
        case .failed(let message):
            Text(message).foregroundStyle(palette.danger)
            Button("Retry preview") { Task { await model.loadPreview() } }
        case .idle, .ready:
            Text(model.preferences.isConfigured
                 ? "No eligible words found. Check the fields or add vocabulary cards to this deck."
                 : "Choose a source to preview a word before enabling the widget.")
                .foregroundStyle(palette.textSecondary)
        }
    }

    private var rotationSection: some View {
        Section {
            Picker("Change word", selection: Binding(
                get: { model.preferences.rotationHours }, set: { model.preferences.intervalHours = $0 }
            )) {
                Text("Daily").tag(24)
                Text("Every hour").tag(1)
                Text("Every 3 hours").tag(3)
                Text("Every 6 hours").tag(6)
                Text("Every 12 hours").tag(12)
            }
        } footer: {
            Text("Changes save automatically for your active source. iOS schedules widget updates, which may appear later.")
        }
    }

    private var notificationsSection: some View {
        Section {
            Toggle("Daily notification", isOn: $model.preferences.notifications)
            if model.preferences.notifications {
                DatePicker("Time", selection: notificationTime, displayedComponents: .hourAndMinute)
                Toggle("Show word in notification", isOn: $model.preferences.showWord)
            }
            if model.controller.notificationsDenied {
                Text("Notifications are disabled in system settings.")
                    .foregroundStyle(palette.textSecondary)
                Button("Open Notification Settings") {
                    guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }
            }
        } footer: {
            Text("Optional, silent reminders. Open Amgi at least every two weeks to prepare more words. Time-zone changes take effect next time you open the app.")
        }
    }

    private func wordContent(_ word: SpotlightWord) -> some View {
        VStack(alignment: .leading, spacing: AmgiSpacing.sm) {
            Text(word.term).amgiFont(.sectionHeading)
            if !word.reading.isEmpty { Text(word.reading).foregroundStyle(palette.textSecondary) }
            Text(word.meaning)
        }
        .textSelection(.enabled)
    }

    private func fieldPicker(_ title: String, selection: Binding<String>) -> some View {
        Picker(title, selection: selection) {
            Text("None").tag("")
            ForEach(model.fields, id: \.self) { Text($0).tag($0) }
        }
        .disabled(model.fields.isEmpty)
    }

    private var notificationTime: Binding<Date> {
        Binding {
            Calendar.current.date(bySettingHour: model.preferences.hour, minute: model.preferences.minute, second: 0, of: .now) ?? .now
        } set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            model.preferences.hour = parts.hour ?? 9
            model.preferences.minute = parts.minute ?? 0
        }
    }
}
