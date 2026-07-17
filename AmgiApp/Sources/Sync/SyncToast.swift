import SwiftUI
import AmgiTheme
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
        .background(.thinMaterial, in: Capsule())
        .overlay(Capsule().stroke(.quaternary, lineWidth: 0.5))
        .amgiChromeShadow(Capsule(), radius: 8, y: 2, opacity: 0.12)
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
