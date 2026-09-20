//
//  ImportStatusBanner.swift
//  AppShared
//
//  Created by Vladimir Gusev on 18.09.2026.
//

import SwiftUI
import Theme

struct ImportStatusBanner: View {
    enum Status: Equatable {
        case importing(fileName: String)
        case finished(summary: String)
    }

    let status: Status?

    var body: some View {
        if let status {
            HStack(spacing: 8) {
                switch status {
                case .importing:
                    ProgressView().controlSize(.small)
                case .finished:
                    Image(systemName: "checkmark.circle.fill")
                }
                Text(label(for: status))
                    .amgiFont(.caption)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .amgiMaterial(.light, in: Capsule())
            .padding(.top, 8)
            .transition(AmgiMotion.slide(from: .top))
        }
    }

    private func label(for status: Status) -> String {
        switch status {
        case .importing(let fileName): "Importing \(fileName)…"
        case .finished(let summary): summary
        }
    }
}
