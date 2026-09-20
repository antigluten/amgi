//
//  SyncToast.swift
//  SyncFeature
//
//  Created by Vladimir Gusev on 04.05.2026.
//

import SwiftUI
import Theme
import UI
import AnkiKit

struct SyncToast: View {
    enum Kind: Equatable {
        case progress(String)
        case success(String)
    }

    @Environment(\.palette) private var palette

    let kind: Kind

    var body: some View {
        HStack(spacing: 10) {
            switch kind {
            case .progress(let message):
                ProgressView()
                    .controlSize(.small)
                Text(message)
            case .success(let message):
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(palette.positive)
                Text(message)
            }
        }
        .amgiFont(.body)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .amgiMaterial(.light, in: Capsule())
        // No hairline overlay here: `amgiMaterialElevation` already draws the
        // ring under a `.ring` palette and drops it under glass. A second
        // stroke double-drew the edge on iOS 26, which is the one thing that
        // seam exists to prevent.
        .amgiMaterialElevation(Capsule(), radius: 8, y: 2, opacity: 0.12)
        .padding(.bottom, 12)
    }
}

extension SyncToast {
    static func summaryMessage(for summary: SyncSummary) -> String {
        if summary.cardsPulled == 0 && summary.cardsPushed == 0 {
            return "Already up to date"
        }
        var parts: [String] = []
        if summary.cardsPulled > 0 { parts.append("\u{2193} \(summary.cardsPulled) received") }
        if summary.cardsPushed > 0 { parts.append("\u{2191} \(summary.cardsPushed) sent") }
        return "Synced — " + parts.joined(separator: ", ")
    }
}
