import SwiftUI

struct AboutView: View {
    private var appVersion: String {
        let bundle = Bundle.main
        let short = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = bundle.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(short) (\(build))"
    }

    var body: some View {
        Form {
            Section("Amgi") {
                LabeledContent("Version", value: appVersion)
                LabeledContent("Korean origin", value: "암기 — memorization")
            }

            Section("Acknowledgements") {
                LabeledContent("Anki engine", value: "ankitects/anki")
                LabeledContent("Community", value: "DreamAfar — fork contributor")
            }

            Section {
                Text("Amgi uses the official Anki Rust backend. The backend code is licensed under AGPL-3.0 and remains the work of its authors.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("About")
    }
}
