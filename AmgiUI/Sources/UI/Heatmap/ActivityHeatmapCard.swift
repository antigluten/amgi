//
//  ActivityHeatmapCard.swift
//  UI
//
//  Created by Vladimir Gusev on 15.05.2026.
//

// iOS-only component — Menu/popover/listRowSeparator APIs are unavailable on watchOS.
#if !os(watchOS)
public import SwiftUI
import Theme

/// GitHub-contribution-style review history grid.
/// Pure rendering — no network I/O. `HeatmapCardData` is pre-computed
/// by the container before being passed in.
/// Placed in the Library list below the deck rows (order: hero → decks → heatmap).
@MainActor
public struct ActivityHeatmapCard: View {
    public let data: HeatmapCardData

    /// Session-only range selection. Default: 180 days (26 weeks).
    @State private var selectedDays: Int = 180
    /// The cell (day offset) currently shown in the popover tooltip.
    @State private var tooltipOffset: Int? = nil
    /// Rebuilds the grid only when the range, counts, or calendar day change —
    /// keeping ~370 cells' worth of date math out of every `body` pass.
    @State private var gridCache = HeatmapGridCache()

    @Environment(\.palette) private var palette

    public init(data: HeatmapCardData) {
        self.data = data
    }

    // MARK: - Computed grid geometry

    private let cellSize: CGFloat = 11
    private let cellSpacing: CGFloat = 2
    private let weekdayLabelWidth: CGFloat = 18

    private var grid: HeatmapGrid {
        gridCache.grid(weekCount: selectedDays / 7 + 1, counts: data.counts)
    }

    // MARK: - Summary stats (filtered to selectedDays)

    private var summary: HeatmapSummary {
        HeatmapSummary(counts: data.counts, selectedDays: selectedDays)
    }

    // MARK: - Body

    public var body: some View {
        AmgiCard(background: .surfaceElevated, shadow: nil) {
            VStack(alignment: .leading, spacing: 12) {
                HeatmapHeaderRow(selectedDays: $selectedDays)
                if data.counts.isEmpty {
                    HeatmapEmptyLabel()
                } else {
                    HeatmapSummaryRow(summary: summary)
                    HeatmapScrollGrid(
                        grid: grid,
                        maxCount: data.maxCount,
                        cellSize: cellSize,
                        cellSpacing: cellSpacing,
                        weekdayLabelWidth: weekdayLabelWidth,
                        tooltipOffset: $tooltipOffset
                    )
                    HeatmapLegend(cellSize: cellSize)
                }
            }
        }
    }
}

// MARK: - Header (title + range menu)

private struct HeatmapHeaderRow: View {
    @Binding var selectedDays: Int
    @Environment(\.palette) private var palette

    var body: some View {
        HStack {
            Text("Activity")
                .amgiFont(.sectionHeading)
                .foregroundStyle(palette.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Menu {
                ForEach([90, 180, 365], id: \.self) { days in
                    Button(rangeLabel(days)) { selectedDays = days }
                }
            } label: {
                Label(rangeLabel(selectedDays), systemImage: "line.horizontal.3.decrease.circle")
                    .amgiFont(.caption)
                    .foregroundStyle(palette.accent)
            }
        }
    }

    private func rangeLabel(_ days: Int) -> String {
        switch days {
        case 90:  return "Last 90 days"
        case 180: return "Last 6 months"
        case 365: return "Last 1 year"
        default:  return "\(days) days"
        }
    }
}

// MARK: - Empty state

private struct HeatmapEmptyLabel: View {
    @Environment(\.palette) private var palette

    var body: some View {
        Text("No reviews yet")
            .amgiFont(.body)
            .foregroundStyle(palette.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
    }
}

// MARK: - Summary row (above grid)

/// The four figures above the grid.
///
/// Derived in a single pass: as four separate computed properties on the card
/// these re-filtered `counts` — up to 365 entries — once per figure, four
/// times per `body` pass. `now` is injectable for the same reason
/// `HeatmapGrid.build` takes it: the month and week figures are relative to
/// the current date, so pinning them needs a fixed clock.
struct HeatmapSummary: Equatable {
    let total: Int
    let thisMonth: Int
    let thisWeek: Int
    let today: Int

    init(
        counts: [Int: Int],
        selectedDays: Int,
        now: Date = Date(),
        calendar: Calendar = .current
    ) {
        let filtered = counts.filter { $0.key >= -selectedDays && $0.key <= 0 }
        let dayOfMonth = calendar.component(.day, from: now)
        let weekday = calendar.component(.weekday, from: now)
        let daysFromMonday = (weekday + 5) % 7

        self.total = filtered.values.reduce(0, +)
        self.thisMonth = (0..<dayOfMonth).reduce(0) { $0 + (filtered[-$1] ?? 0) }
        self.thisWeek = (0...daysFromMonday).reduce(0) { $0 + (filtered[-$1] ?? 0) }
        self.today = filtered[0] ?? 0
    }
}

private struct HeatmapSummaryRow: View {
    let summary: HeatmapSummary

    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 0) {
            summaryItem(value: summary.total, label: "Total")
            summaryItem(value: summary.thisMonth, label: "Month")
            summaryItem(value: summary.thisWeek, label: "Week")
            summaryItem(value: summary.today, label: "Today")
        }
    }

    private func summaryItem(value: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .amgiFont(.captionBold, .monospacedDigits)
                .foregroundStyle(palette.textPrimary)
            Text(label)
                .amgiFont(.micro)
                .foregroundStyle(palette.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Scrollable grid

private struct HeatmapScrollGrid: View {
    let grid: HeatmapGrid
    let maxCount: Int
    let cellSize: CGFloat
    let cellSpacing: CGFloat
    let weekdayLabelWidth: CGFloat
    @Binding var tooltipOffset: Int?

    var body: some View {
        ScrollView(.horizontal) {
            VStack(alignment: .leading, spacing: 0) {
                HeatmapMonthHeader(
                    grid: grid,
                    cellSize: cellSize,
                    cellSpacing: cellSpacing,
                    weekdayLabelWidth: weekdayLabelWidth
                )
                HeatmapCellGrid(
                    grid: grid,
                    maxCount: maxCount,
                    cellSize: cellSize,
                    cellSpacing: cellSpacing,
                    weekdayLabelWidth: weekdayLabelWidth,
                    tooltipOffset: $tooltipOffset
                )
            }
        }
        .scrollIndicators(.never)
        .defaultScrollAnchor(.trailing)
    }
}

// MARK: - Month header

private struct HeatmapMonthHeader: View {
    let grid: HeatmapGrid
    let cellSize: CGFloat
    let cellSpacing: CGFloat
    let weekdayLabelWidth: CGFloat

    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 0) {
            Spacer().frame(width: weekdayLabelWidth)
            ForEach(grid.weeks) { week in
                if let label = week.monthLabel {
                    Text(label)
                        .font(.system(size: 9))
                        .foregroundStyle(palette.textSecondary)
                        .fixedSize()
                        .frame(width: cellSize + cellSpacing, alignment: .leading)
                } else {
                    Spacer().frame(width: cellSize + cellSpacing)
                }
            }
        }
        .frame(height: 14)
    }
}

// MARK: - Cell grid

private struct HeatmapCellGrid: View {
    let grid: HeatmapGrid
    let maxCount: Int
    let cellSize: CGFloat
    let cellSpacing: CGFloat
    let weekdayLabelWidth: CGFloat
    @Binding var tooltipOffset: Int?

    @Environment(\.palette) private var palette

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            weekdayColumnLabels
            HStack(spacing: cellSpacing) {
                ForEach(grid.weeks) { week in
                    VStack(spacing: cellSpacing) {
                        ForEach(week.days) { day in
                            HeatmapCell(
                                day: day,
                                maxCount: maxCount,
                                cellSize: cellSize,
                                isShowingTooltip: tooltipOffset == day.offset,
                                onTap: {
                                    tooltipOffset = tooltipOffset == day.offset ? nil : day.offset
                                },
                                onDismiss: { tooltipOffset = nil }
                            )
                        }
                    }
                }
            }
        }
    }

    private var weekdayColumnLabels: some View {
        VStack(spacing: cellSpacing) {
            ForEach(0..<7, id: \.self) { dayIndex in
                Text(weekdayLabel(dayIndex))
                    .font(.system(size: 8))
                    .foregroundStyle(palette.textSecondary)
                    .frame(width: weekdayLabelWidth, height: cellSize)
            }
        }
    }

    private func weekdayLabel(_ index: Int) -> String {
        switch index {
        case 1: "M"
        case 3: "W"
        case 5: "F"
        default: ""
        }
    }
}

// MARK: - Single cell with popover tooltip

private struct HeatmapCell: View {
    let day: HeatmapDay
    let maxCount: Int
    let cellSize: CGFloat
    let isShowingTooltip: Bool
    let onTap: () -> Void
    let onDismiss: () -> Void

    @Environment(\.palette) private var palette

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        // The `.popover` is attached only to the cell actually showing one.
        // Attaching it unconditionally would stand up a presentation host for
        // every cell in the grid — ~370 of them at the 1-year range.
        if isShowingTooltip {
            cellButton.popover(
                isPresented: Binding(get: { true }, set: { if !$0 { onDismiss() } })
            ) {
                tooltip.presentationCompactAdaptation(.popover)
            }
        } else {
            cellButton
        }
    }

    private var cellButton: some View {
        Button(action: onTap) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(cellColor)
                .frame(width: cellSize, height: cellSize)
        }
        .buttonStyle(.pressScale)
    }

    private var tooltip: some View {
        VStack(spacing: 4) {
            Text(Self.dateFormatter.string(from: day.date))
                .amgiFont(.captionBold)
            Text(day.count == 0 ? "No reviews" : "\(day.count) review\(day.count == 1 ? "" : "s")")
                .amgiFont(.caption)
        }
        .padding(10)
    }

    private var cellColor: Color {
        guard !day.isFuture else { return Color.clear }
        return HeatmapColorRamp.color(count: day.count, maxCount: maxCount, palette: palette)
    }
}

// MARK: - Legend strip

private struct HeatmapLegend: View {
    let cellSize: CGFloat
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 4) {
            Text("Less").amgiFont(.micro).foregroundStyle(palette.textSecondary)
            ForEach(
                Array(HeatmapColorRamp.legendColors(palette: palette).enumerated()),
                id: \.offset
            ) { _, color in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(color)
                    .frame(width: cellSize, height: cellSize)
            }
            Text("More").amgiFont(.micro).foregroundStyle(palette.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Empty") {
    ActivityHeatmapCard(data: .empty)
        .padding(16)
        .background(Color.gray.opacity(0.1))
        .environment(\.palette, .vividLight)
}

#Preview("Sparse") {
    ActivityHeatmapCard(data: .sparse)
        .padding(16)
        .background(Color.gray.opacity(0.1))
        .environment(\.palette, .vividLight)
}

#Preview("Dense") {
    ActivityHeatmapCard(data: .dense)
        .padding(16)
        .background(Color.gray.opacity(0.1))
        .environment(\.palette, .vividLight)
}

#Preview("Streak — Muted theme") {
    ActivityHeatmapCard(data: .streak)
        .padding(16)
        .background(Color.gray.opacity(0.1))
        .environment(\.palette, .mutedLight)
}

#Preview("Dense — dark mode") {
    ActivityHeatmapCard(data: .dense)
        .padding(16)
        .background(Color.black)
        .environment(\.palette, .vividDark)
        .preferredColorScheme(.dark)
}
#endif
#endif  // !os(watchOS)
