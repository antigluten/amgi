//
//  OnboardingView.swift
//  SyncFeature
//
//  Created by Vladimir Gusev on 30.03.2026.
//

package import SwiftUI
import Theme
import UI
import AppCore
import AnkiSync
import Sharing

package struct OnboardingView: View {
    @Environment(\.palette) private var palette
    @Shared(.onboardingCompleted) private var onboardingCompleted
    @Shared(.syncMode) private var syncMode
    @State private var showServerSetup = false
    @State private var showSyncChoice = false
    @State private var serverURL = ""
    @State private var endpointError: String?

    package init() {}

    @ViewBuilder
    package var body: some View {
        if showSyncChoice {
            syncChoice
        } else {
            WelcomeFlowView {
                withAnimation(AmgiMotion.standard) { showSyncChoice = true }
            }
            .transition(AmgiMotion.reveal)
        }
    }

    private var syncChoice: some View {
        VStack(spacing: AmgiSpacing.xxl) {
            Spacer()

            Image(systemName: "rectangle.stack.fill")
                .font(.system(size: 64))
                .foregroundStyle(palette.accent)

            Text("Stay in sync")
                .amgiFont(.displayHero)
                .foregroundStyle(palette.textPrimary)

            Text("Choose how to sync your collection")
                .amgiFont(.body)
                .foregroundStyle(palette.textSecondary)

            VStack(spacing: AmgiSpacing.md) {
                if showServerSetup {
                    VStack(spacing: AmgiSpacing.md) {
                        AnkiMobileAttributionView()
                            .padding(.horizontal)

                        TextField("Server URL", text: $serverURL)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            .padding(.horizontal)

                        if let endpointError {
                            Text(endpointError)
                                .amgiStatusText(.danger, font: .caption)
                                .padding(.horizontal)
                        }

                        Button("Continue") {
                            saveAndContinue()
                        }
                        .buttonStyle(AmgiPrimaryButtonStyle())
                        .disabled(serverURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        Button("Back") {
                            withAnimation(AmgiMotion.standard) { showServerSetup = false }
                        }
                        .amgiFont(.caption)
                        .foregroundStyle(palette.textSecondary)
                    }
                    .transition(.opacity)
                } else {
                    VStack(spacing: AmgiSpacing.md) {
                        Button {
                            withAnimation(AmgiMotion.standard) { showServerSetup = true }
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
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, 32)

            Text("You can change this anytime in sync settings")
                .amgiFont(.micro)
                .foregroundStyle(palette.textTertiary)

            Spacer()
        }
        .background(palette.background)
    }

}

private extension OnboardingView {
    func saveAndContinue() {
        do {
            let url = try SyncEndpoint.normalized(serverURL)
            try KeychainHelper.saveEndpoint(url)
            endpointError = nil
            $syncMode.withLock { $0 = .custom }
            $onboardingCompleted.withLock { $0 = true }
        } catch {
            endpointError = error.localizedDescription
        }
    }
}

#if DEBUG

// MARK: - Preview

#Preview {
    OnboardingView()
}
#endif
