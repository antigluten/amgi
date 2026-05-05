import AnkiClients
import AnkiKit
import AnkiSync
import Dependencies
import SwiftUI

struct WatchLoginView: View {
    @State private var username = ""
    @State private var password = ""
    @State private var endpoint = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showLoginFields = false
    var onLoginSuccess: () -> Void
    var body: some View {
        ScrollView {
            VStack {
                loginFieldsView
            }
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
            TextField("Server URL", text: $endpoint)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            TextField("Username", text: $username)
                .textContentType(.username)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            SecureField("Password", text: $password)
                .textContentType(.password)
            if let error = errorMessage {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task { await login() }
            } label: {
                if isLoading {
                    ProgressView()
                } else {
                    Text("Sign In")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(username.isEmpty || password.isEmpty || isLoading)
        }
    }
    private func login() async {
        isLoading = true
        errorMessage = nil
        // Persist endpoint if provided
        let ep = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        if !ep.isEmpty {
            // Ignore errors here; login flow should still proceed
            try? KeychainHelper.saveEndpoint(ep)
        }
        do {
            _ = try await SyncClient.login(username: username, password: password)
            // Initial sync to get the collection
            @Dependency(\.syncClient) var syncClient
            _ = try await syncClient.sync()
            onLoginSuccess()
        } catch {
            errorMessage = "Login failed. Check your credentials."
            print("[WatchLogin] Error: \(error)")
        }
        isLoading = false
    }
}
