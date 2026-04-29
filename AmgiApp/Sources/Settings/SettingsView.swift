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

            Section("Sync") {
                NavigationLink("Sync Server") {
                    SyncSettingsView()
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
