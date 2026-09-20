//
//  WelcomeFlowView.swift
//  SyncFeature
//
//  Created by Vladimir Gusev on 18.09.2026.
//

import SwiftUI
import Theme
import UI
import AppShared

struct WelcomeFlowView: View {
    @Environment(\.palette) private var palette
    @State private var step = 0

    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            skipRow
            pages
            pageDots
            continueButton
        }
        .background(backdrop)
    }
}

// MARK: - Steps

private struct WelcomeStep {
    let eyebrow: LocalizedStringKey
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    var cta: LocalizedStringKey?
}

private extension WelcomeFlowView {
    var steps: [WelcomeStep] {
        [
            WelcomeStep(
                eyebrow: "Welcome to",
                title: "Amgi",
                subtitle: "Remember everything you learn — with cards that schedule themselves."
            ),
            WelcomeStep(
                eyebrow: "How it works",
                title: "Spaced repetition,\nbeautifully tuned.",
                subtitle: """
                    Amgi shows each card exactly when you're about to forget. \
                    The longer you remember, the rarer it returns.
                    """
            ),
            WelcomeStep(
                eyebrow: "Built-in Reader",
                title: "Read. Tap. Remember.",
                subtitle: """
                    Import a book and look up unfamiliar words as you read, \
                    without leaving the page.
                    """
            ),
            WelcomeStep(
                eyebrow: "You're ready",
                title: "Let's build a habit.",
                subtitle: """
                    Import a deck and start reviewing. \
                    Five minutes a day is all it takes.
                    """,
                cta: "Start learning"
            ),
        ]
    }

    var current: WelcomeStep { steps[step] }
    var isLastStep: Bool { step == steps.count - 1 }

    func advance() {
        guard !isLastStep else { return onDone() }
        withAnimation(AmgiMotion.standard) { step += 1 }
    }

    func retreat() {
        guard step > 0 else { return }
        withAnimation(AmgiMotion.standard) { step -= 1 }
    }

    func select(_ index: Int) {
        guard index != step else { return }
        withAnimation(AmgiMotion.standard) { step = index }
    }
}

// MARK: - Composition

private extension WelcomeFlowView {
    var backdrop: some View {
        LinearGradient(
            colors: [palette.surface, palette.background],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    @ViewBuilder
    var skipRow: some View {
        HStack {
            Spacer()
            if !isLastStep {
                Button("Skip", action: onDone)
                    .amgiFont(.body)
                    .foregroundStyle(palette.textSecondary)
                    // RULES.md §1 — the label is 17pt, the hit region is 44pt.
                    .frame(minWidth: 44, minHeight: 44)
            }
        }
        .frame(minHeight: 44)
        .padding(.horizontal, AmgiSpacing.md)
    }

    @ViewBuilder
    var pages: some View {
        #if os(iOS)
        TabView(selection: $step) {
            ForEach(steps.indices, id: \.self) { index in
                page(index).tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        #else
        page(step)
            .id(step)
            .transition(AmgiMotion.reveal)
        #endif
    }

    func page(_ index: Int) -> some View {
        VStack(spacing: 0) {
            visual(index)
            copy(steps[index])
        }
    }

    func visual(_ index: Int) -> some View {
        stepVisual(index)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, AmgiSpacing.xl)
            .accessibilityHidden(true)
            .dynamicTypeSize(...DynamicTypeSize.large)
    }

    @ViewBuilder
    func stepVisual(_ index: Int) -> some View {
        switch index {
        case 0: StackedCardsVisual()
        case 1: IntervalVisual()
        case 2: ReaderVisual()
        default: ReadyVisual()
        }
    }

    func copy(_ step: WelcomeStep) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(step.eyebrow)
                .amgiFont(size: 13, weight: .semibold, tracking: 0.6, relativeTo: .footnote)
                .textCase(.uppercase)
                .foregroundStyle(palette.accent)
                .padding(.bottom, AmgiSpacing.sm)

            Text(step.title)
                .amgiFont(.displayHero)
                .foregroundStyle(palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(step.subtitle)
                .amgiFont(.body)
                .lineSpacing(3)
                .foregroundStyle(palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, AmgiSpacing.md)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AmgiSpacing.xxl)
    }

    var pageDots: some View {
        HStack(spacing: 0) {
            ForEach(steps.indices, id: \.self) { index in
                Button { select(index) } label: {
                    Capsule()
                        .fill(index == step ? palette.accent : palette.separator)
                        .frame(width: index == step ? 22 : 7, height: 7)
                        .frame(width: 28, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Step \(index + 1) of \(steps.count)")
                .accessibilityAddTraits(index == step ? [.isSelected] : [])
            }
        }
    }

    var continueButton: some View {
        Button(action: advance) {
            Text(current.cta ?? "Continue")
                .frame(maxWidth: .infinity)
                // 28 + the style's 8pt vertical padding on each side = 44.
                .frame(minHeight: 28)
        }
        .buttonStyle(AmgiPrimaryButtonStyle())
        .padding(.horizontal, AmgiSpacing.xl)
        .padding(.bottom, AmgiSpacing.xxl)
    }
}

// MARK: - Step 1 · stacked cards

private struct StackedCardsVisual: View {
    @Environment(\.palette) private var palette

    private static let cardSize = CGSize(width: 160, height: 220)

    var body: some View {
        ZStack {
            card(depth: 2)
            card(depth: 1)
            card(depth: 0)
        }
        .frame(width: 220, height: 260)
    }

    @ViewBuilder
    private func card(depth: Int) -> some View {
        let shape = RoundedRectangle(cornerRadius: AmgiRadius.card, style: .continuous)
        shape
            .fill(fill(depth: depth))
            .frame(width: Self.cardSize.width, height: Self.cardSize.height)
            .overlay {
                if depth == 0 {
                    Text(verbatim: "A")
                        .amgiFont(size: 92, weight: .bold, tracking: 0.22, relativeTo: .largeTitle)
                        .foregroundStyle(.white)
                }
            }
            .amgiChromeShadow(shape, radius: 15, y: 12, opacity: 0.10)
            .rotationEffect(.degrees(Double(2 - depth) * 4))
            .offset(x: CGFloat(depth) * -14, y: CGFloat(depth) * -10)
    }

    private func fill(depth: Int) -> AnyShapeStyle {
        switch depth {
        case 0:
            AnyShapeStyle(LinearGradient(
                colors: [palette.accent, palette.cardStateMature],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
        case 1:
            AnyShapeStyle(palette.surface)
        default:
            AnyShapeStyle(palette.border)
        }
    }
}

// MARK: - Step 2 · forgetting curve

private struct IntervalVisual: View {
    @Environment(\.palette) private var palette

    private static let axisY: CGFloat = 175
    private static let marks: [(x: CGFloat, label: String)] = [
        (6, "10m"), (22, "1d"), (42, "3d"), (66, "10d"), (92, "1mo"),
    ]

    var body: some View {
        ZStack(alignment: .topLeading) {
            memoryCurve
            axis
            ForEach(Array(Self.marks.enumerated()), id: \.offset) { index, mark in
                pulse(index: index, mark: mark)
            }
            axisCaption("MEMORY STRENGTH", y: 8)
            axisCaption("TIME →", y: Self.axisY + 24)
        }
        .frame(width: 280, height: 230)
    }

    private var memoryCurve: some View {
        Path { path in
            path.move(to: CGPoint(x: 20, y: 50))
            path.addQuadCurve(to: CGPoint(x: 60, y: 95), control: CGPoint(x: 40, y: 65))
            path.addQuadCurve(to: CGPoint(x: 95, y: 130), control: CGPoint(x: 80, y: 130))
            path.addQuadCurve(to: CGPoint(x: 130, y: 80), control: CGPoint(x: 110, y: 60))
            path.addQuadCurve(to: CGPoint(x: 165, y: 110), control: CGPoint(x: 150, y: 110))
            path.addQuadCurve(to: CGPoint(x: 200, y: 70), control: CGPoint(x: 180, y: 50))
            path.addQuadCurve(to: CGPoint(x: 235, y: 100), control: CGPoint(x: 220, y: 100))
            path.addQuadCurve(to: CGPoint(x: 265, y: 75), control: CGPoint(x: 250, y: 60))
        }
        .stroke(
            palette.accent.opacity(0.35),
            style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [4, 4])
        )
    }

    private var axis: some View {
        Path { path in
            path.move(to: CGPoint(x: 14, y: Self.axisY))
            path.addLine(to: CGPoint(x: 266, y: Self.axisY))
        }
        .stroke(palette.separator, lineWidth: 1.5)
    }

    @ViewBuilder
    private func pulse(index: Int, mark: (x: CGFloat, label: String)) -> some View {
        let centerX = 20 + (mark.x / 100) * 240
        let stemTop = Self.axisY - 35 - CGFloat(index) * 12

        Path { path in
            path.move(to: CGPoint(x: centerX, y: Self.axisY))
            path.addLine(to: CGPoint(x: centerX, y: stemTop))
        }
        .stroke(
            palette.accent.opacity(0.9),
            style: StrokeStyle(lineWidth: 2, lineCap: .round)
        )

        dot(diameter: 8).position(x: centerX, y: stemTop)
        dot(diameter: 10).position(x: centerX, y: Self.axisY)

        Text(mark.label)
            .amgiFont(.micro)
            .foregroundStyle(palette.textTertiary)
            .position(x: centerX, y: Self.axisY + 14)
    }

    private func dot(diameter: CGFloat) -> some View {
        Circle()
            .fill(palette.accent)
            .frame(width: diameter, height: diameter)
    }

    private func axisCaption(_ text: String, y: CGFloat) -> some View {
        Text(text)
            .amgiFont(size: 11, weight: .medium, tracking: 0.4, relativeTo: .caption2)
            .foregroundStyle(palette.textTertiary)
            .offset(x: 14, y: y)
    }
}

// MARK: - Step 3 · reader lookup

private struct ReaderVisual: View {
    @Environment(\.palette) private var palette

    private static let term = "멋있는"
    private static let sentence = "나는 여섯 살 때 책에서 멋있는 그림을 본 적이 있습니다."

    private var page: Color {
        ReaderThemeColor.color(fromHex: "#F4ECD8", fallback: palette.surface)
    }

    private var ink: Color {
        ReaderThemeColor.color(fromHex: "#4A3F2A", fallback: palette.textPrimary)
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: AmgiRadius.hero, style: .continuous)

        ZStack(alignment: .bottom) {
            Text(passage)
                .amgiFont(.serifTitle)
                .foregroundStyle(ink)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            popup
        }
        .padding(AmgiSpacing.xl)
        .frame(width: 240, height: 260)
        .background(page, in: shape)
        .amgiChromeShadow(shape, radius: 15, y: 14, opacity: 0.18)
    }

    private var passage: AttributedString {
        var text = AttributedString(Self.sentence)
        if let range = text.range(of: Self.term) {
            text[range].backgroundColor = palette.accentSoft
            text[range].underlineStyle = Text.LineStyle(pattern: .solid, color: palette.accent)
        }
        return text
    }

    private var popup: some View {
        let shape = RoundedRectangle(cornerRadius: AmgiRadius.inset, style: .continuous)

        return VStack(alignment: .leading, spacing: AmgiSpacing.xxs) {
            Text(verbatim: "\(Self.term) · adj.")
                .amgiFont(size: 11, weight: .semibold, tracking: 0.5, relativeTo: .caption2)
                .textCase(.uppercase)
                .foregroundStyle(palette.accent)

            Text("cool, stylish, splendid")
                .amgiFont(.caption)
                .foregroundStyle(palette.textPrimary)

            HStack(spacing: AmgiSpacing.xs) {
                chip("Look up", systemImage: "character.book.closed", isProminent: true)
                chip("Save", systemImage: nil, isProminent: false)
            }
            .padding(.top, AmgiSpacing.sm)
        }
        .padding(.horizontal, AmgiSpacing.md)
        .padding(.vertical, AmgiSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surface, in: shape)
        .amgiChromeShadow(shape, radius: 12, y: 8, opacity: 0.18)
    }

    private func chip(_ title: String, systemImage: String?, isProminent: Bool) -> some View {
        HStack(spacing: AmgiSpacing.xs) {
            if let systemImage {
                Image(systemName: systemImage)
            }
            Text(title)
        }
        .amgiFont(size: 12, weight: isProminent ? .semibold : .medium, relativeTo: .caption)
        .foregroundStyle(isProminent ? AnyShapeStyle(.white) : AnyShapeStyle(palette.textPrimary))
        .padding(.horizontal, AmgiSpacing.sm)
        .padding(.vertical, AmgiSpacing.xs)
        .background(
            isProminent ? AnyShapeStyle(palette.accent) : AnyShapeStyle(palette.accentSoft),
            in: RoundedRectangle(cornerRadius: AmgiRadius.small, style: .continuous)
        )
    }
}

// MARK: - Step 4 · ready

private struct ReadyVisual: View {
    @Environment(\.palette) private var palette

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [palette.accentSoft, palette.accent],
                    center: UnitPoint(x: 0.3, y: 0.3),
                    startRadius: 0,
                    endRadius: 170
                ))

            Circle()
                .strokeBorder(
                    .white.opacity(0.6),
                    style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                )
                .padding(AmgiSpacing.xl)

            Image(systemName: "sparkles")
                .font(.system(size: 72, weight: .light))
                .foregroundStyle(.white)
        }
        .frame(width: 240, height: 240)
        .amgiChromeShadow(Circle(), radius: 25, y: 24, opacity: 0.22)
    }
}

#if DEBUG

// MARK: - Preview

#Preview {
    WelcomeFlowView(onDone: {})
}
#endif
