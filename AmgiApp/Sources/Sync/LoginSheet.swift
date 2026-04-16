import SwiftUI
import AnkiClients
import AnkiSync

struct LoginSheet: View {
    @Binding var isPresented: Bool
    let onSuccess: () -> Void

    @State private var username = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Username", text: $username)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    SecureField("Password", text: $password)
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
                Section {
                    Button {
                        Task { await login() }
                    } label: {
                        if isLoading {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Text("Sign In").frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(username.isEmpty || password.isEmpty || isLoading)
                }
            }
            .navigationTitle("Login")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
            }
        }
    }

    private func login() async {
        isLoading = true
        errorMessage = nil
        do {
            _ = try await SyncClient.login(username: username, password: password)
            isPresented = false
            onSuccess()
        } catch {
            errorMessage = "Login failed. Check your username and password."
        }
        isLoading = false
    }
}
