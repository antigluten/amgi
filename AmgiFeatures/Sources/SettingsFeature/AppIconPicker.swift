//
//  AppIconPicker.swift
//  SettingsFeature
//

#if os(iOS)
import SwiftUI
import UIKit
import Theme
import UI

struct AppIconPicker: View {
    @Environment(\.palette) private var palette
    @State private var selection: AppIconOption?
    @State private var isSwitching = false
    @State private var errorMessage: String?

    private static let columns = Array(repeating: GridItem(.flexible(), spacing: AmgiSpacing.md), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: AmgiSpacing.sm) {
            grid
            if let errorMessage {
                Text(errorMessage)
                    .amgiFont(.micro)
                    .foregroundStyle(palette.danger)
            }
        }
        .padding(.horizontal, AmgiSpacing.lg)
        .onAppear {
            selection = AppIconOption(alternateName: UIApplication.shared.alternateIconName)
        }
    }

    private var grid: some View {
        LazyVGrid(columns: Self.columns, spacing: AmgiSpacing.lg) {
            ForEach(AppIconOption.allCases) { option in
                AppIconTile(option: option, isSelected: option == selection) {
                    select(option)
                }
            }
        }
        .disabled(isSwitching)
    }

    private func select(_ option: AppIconOption) {
        guard option != selection, !isSwitching else { return }
        let previous = selection
        selection = option
        errorMessage = nil
        isSwitching = true
        Task {
            defer { isSwitching = false }
            do {
                try await UIApplication.shared.setAlternateIconName(option.alternateName)
            } catch {
                selection = previous
                errorMessage = error.localizedDescription
            }
        }
    }
}

private struct AppIconTile: View {
    let option: AppIconOption
    let isSelected: Bool
    let onTap: () -> Void

    @Environment(\.palette) private var palette

    private static let size: CGFloat = 64
    private static let corner = size * 0.2237
    private static let ringGap = AmgiSpacing.xs

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: AmgiSpacing.sm) {
                icon
                Text(option.displayName)
                    .amgiFont(.micro)
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.pressScale)
        .accessibilityLabel(option.displayName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var icon: some View {
        Image(option.previewName, bundle: .module)
            .resizable()
            .scaledToFit()
            .frame(width: Self.size, height: Self.size)
            .clipShape(RoundedRectangle(cornerRadius: Self.corner, style: .continuous))
            .padding(Self.ringGap)
            .overlay {
                RoundedRectangle(cornerRadius: Self.corner + Self.ringGap, style: .continuous)
                    .strokeBorder(palette.accent, lineWidth: 2)
                    .opacity(isSelected ? 1 : 0)
            }
            .accessibilityHidden(true)
    }
}
#endif
