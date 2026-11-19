//
//  LoginSheet.swift
//  SyncFeature
//
//  Created by Vladimir Gusev on 27.03.2026.
//

import SwiftUI
import Theme
import AnkiClients
import AnkiSync

struct LoginSheet: View {
    @Environment(\.palette) private var palette

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
                    TextField(String(localized: "Username", bundle: .module), text: $username)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    SecureField(String(localized: "Password", bundle: .module), text: $password)
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(palette.danger)
                            .amgiFont(.caption)
                    }
                }
                Section {
                    Button {
                        Task { await login() }
                    } label: {
                        if isLoading {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Text("Sign In", bundle: .module).frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(username.isEmpty || password.isEmpty || isLoading)
                }
            }
            .navigationTitle(String(localized: "Login", bundle: .module))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel", bundle: .module)) { isPresented = false }
                }
            }
        }
    }

}

private extension LoginSheet {
    func login() async {
        isLoading = true
        errorMessage = nil
        do {
            _ = try await SyncClient.login(username: username, password: password)
            isPresented = false
            onSuccess()
        } catch {
            errorMessage = String(localized: "Login failed. Check your username and password.", bundle: .module)
        }
        isLoading = false
    }
}

#if DEBUG

// MARK: - Preview

#Preview {
    LoginSheet(isPresented: .constant(true), onSuccess: {})
}
#endif
