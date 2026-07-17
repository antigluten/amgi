import SwiftUI
import AmgiTheme

struct SettingsView: View {
    var body: some View {
        Form {
            Section("Appearance") {
                NavigationLink("Theme & Appearance") {
                    AppearanceSettingsView(manager: .shared)
                }
            }

            Section("Account") {
                NavigationLink("Profiles") {
                    AccountsSettingsView()
                }
                NavigationLink("Sync Server") {
                    SyncSettingsView()
                }
            }

            Section("Review") {
                NavigationLink("Review Behavior") {
                    ReviewSettingsView()
                }
            }

            Section("Reader") {
                NavigationLink("Reader Display") {
                    ReaderSettingsView()
                }
                NavigationLink("Dictionaries") {
                    ReaderDictionarySettingsView()
                }
            }

            Section("Tags") {
                NavigationLink("Manage Tags") {
                    TagsView()
                }
            }

            Section("Maintenance") {
                NavigationLink("Database") {
                    MaintenanceView()
                }
                NavigationLink("Empty Cards") {
                    EmptyCardsView()
                }
                NavigationLink("Media Check") {
                    MediaCheckResultView()
                }
            }

            Section("Card Templates") {
                NavigationLink("Manage Templates") {
                    DeckTemplateListView()
                }
            }

            Section {
                NavigationLink("About") {
                    AboutView()
                }
            }
        }
        .navigationTitle("Settings")
    }
}
