//
//  WatchLoginView.swift
//  WatchFeature
//
//  Created by Leaf Eriksen on 17.07.2026.
//

import AnkiClients
import AnkiKit
import AnkiSync
import Dependencies
import os
public import SwiftUI

private let logger = Logger(subsystem: "com.amgiapp.AmgiApp", category: "WatchLogin")

public struct WatchLoginView: View {
    @Dependency(\.syncClient) private var syncClient
    @State private var username = ""
    @State private var password = ""
    @State private var endpoint = ""
    /// Form submission state. `showLoginFields` used to sit here too and was
    /// never read.
    enum SubmissionState {
        case idle
        case submitting
        case failed(String)
    }

    @State private var submission: SubmissionState = .idle
    var onLoginSuccess: () -> Void

    public init(onLoginSuccess: @escaping () -> Void) {
        self.onLoginSuccess = onLoginSuccess
    }

    private var isSubmitting: Bool {
        if case .submitting = submission { return true }
        return false
    }
    public var body: some View {
        ScrollView {
            loginFieldsView
        }
        .onAppear {
            // Prefill endpoint from keychain if available
            if let saved = KeychainHelper.loadEndpoint() {
                endpoint = saved
            }
        }
    }
    private var loginFieldsView: some View {
        VStack {
            TextField(String(localized: "Server URL", bundle: .module), text: $endpoint)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            TextField(String(localized: "Username", bundle: .module), text: $username)
                .textContentType(.username)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            SecureField(String(localized: "Password", bundle: .module), text: $password)
                .textContentType(.password)
            if endpoint.lowercased().contains("ankiweb") {
                Text("AnkiWeb is supported by sales of AnkiMobile. Please consider buying it on your iPhone to support the sync servers.", bundle: .module)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            if case .failed(let error) = submission {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
            Button {
                Task { await login() }
            } label: {
                if isSubmitting {
                    ProgressView()
                } else {
                    Text("Sign In", bundle: .module)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(username.isEmpty || password.isEmpty || isSubmitting)
        }
    }
    private func login() async {
        submission = .submitting
        // Persist endpoint if provided
        let ep = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        if ep.isEmpty {
            KeychainHelper.deleteEndpoint()
        } else {
            // Ignore errors here; login flow should still proceed
            try? KeychainHelper.saveEndpoint(ep)
        }
        KeychainHelper.deleteCurrentEndpoint()
        do {
            _ = try await SyncClient.login(username: username, password: password)
            // Initial sync to get the collection
            _ = try await syncClient.sync()
            submission = .idle
            onLoginSuccess()
        } catch {
            logger.error("Login failed: \(error)")
            submission = .failed(String(localized: "Login failed. Check your credentials.", bundle: .module))
        }
    }
}
