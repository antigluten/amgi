import SwiftUI
import AnkiSync
import Sharing

struct OnboardingView: View {
    @Shared(.onboardingCompleted) private var onboardingCompleted
    @Shared(.syncMode) private var syncMode
    @State private var showServerSetup = false
    @State private var serverURL = ""

    var body: some View {
        VStack(spacing: AmgiSpacing.xxl) {
            Spacer()

            Image(systemName: "rectangle.stack.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.amgiAccent)

            Text("Welcome")
                .amgiFont(.displayHero)
                .foregroundStyle(Color.amgiTextPrimary)

            Text("Choose how to sync your collection")
                .amgiFont(.body)
                .foregroundStyle(Color.amgiTextSecondary)

            VStack(spacing: AmgiSpacing.md) {
                if showServerSetup {
                    VStack(spacing: AmgiSpacing.md) {
                        TextField("Server URL", text: $serverURL)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            .padding(.horizontal)

                        Button("Continue") {
                            saveAndContinue()
                        }
                        .buttonStyle(AmgiPrimaryButtonStyle())
                        .disabled(serverURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        Button("Back") {
                            showServerSetup = false
                        }
                        .amgiFont(.caption)
                        .foregroundStyle(Color.amgiTextSecondary)
                    }
                } else {
                    Button {
                        showServerSetup = true
                    } label: {
                        Label("Custom Server", systemImage: "server.rack")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(AmgiPrimaryButtonStyle())

                    Button {
                        $syncMode.withLock { $0 = .local }
                        $onboardingCompleted.withLock { $0 = true }
                    } label: {
                        Label("Use Locally", systemImage: "iphone")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(AmgiSecondaryButtonStyle())
                }
            }
            .padding(.horizontal, 32)

            Text("You can change this anytime in sync settings")
                .amgiFont(.micro)
                .foregroundStyle(Color.amgiTextTertiary)

            Spacer()
        }
        .background(Color.amgiBackground)
    }

    private func saveAndContinue() {
        var url = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !url.hasPrefix("http://") && !url.hasPrefix("https://") {
            url = "https://" + url
        }
        try? KeychainHelper.saveEndpoint(url)
        $syncMode.withLock { $0 = .custom }
        $onboardingCompleted.withLock { $0 = true }
    }
}
