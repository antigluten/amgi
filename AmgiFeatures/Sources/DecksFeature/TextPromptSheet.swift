//
//  TextPromptSheet.swift
//  DecksFeature
//
//  Created by Vladimir Gusev on 17.09.2026.
//

import SwiftUI
import Theme

struct TextPromptSheet: View {
    let title: String
    let placeholder: String
    let footer: String?
    let confirmLabel: String
    var keyboard: UIKeyboardType = .default
    var capitalization: TextInputAutocapitalization = .sentences
    let isValid: (String) -> Bool
    let onConfirm: (String) async -> String?

    @Binding var text: String

    @State private var isWorking = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(placeholder, text: $text)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(capitalization)
                        .keyboardType(keyboard)
                } footer: {
                    if let footer { Text(footer) }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .alert(
                "Couldn't \(confirmLabel.lowercased())",
                isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }),
                presenting: errorMessage
            ) { _ in
                Button("OK") {}
            } message: { message in
                Text(message)
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button(confirmLabel) { Task { await confirm() } }
                .disabled(!isValid(text) || isWorking)
        }
    }

    private func confirm() async {
        isWorking = true
        defer { isWorking = false }
        if let failure = await onConfirm(text) {
            errorMessage = failure
        } else {
            dismiss()
        }
    }
}
