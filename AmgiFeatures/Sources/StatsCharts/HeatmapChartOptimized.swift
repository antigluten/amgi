//
//  HeatmapChartOptimized.swift
//  StatsCharts
//
//  Created by Vladimir Gusev on 29.04.2026.
//

public import SwiftUI
import Theme
import UI
public import AnkiKit

/// Optimized heatmap with incremental loading.
/// - Initially loads 6 months of data.
/// - Loads more when scrolling to edges.
/// - Configurable via the date range menu.
public struct HeatmapChartOptimized: View {
    let reviews: ReviewCountsAndTimes

    public init(reviews: ReviewCountsAndTimes, compactHeight: CGFloat? = nil) {
        self.reviews = reviews
        self.compactHeight = compactHeight
    }

    @Environment(\.palette) private var palette
    @State private var loadingManager: HeatmapLoadingManager?
    @State private var shouldShowLoadingIndicator = false
    @State private var scrollPosition: CGFloat = 0
    @State private var selectedDateRange: Int = 180

    @State private var visibleData: [Int: Int] = [:]
    @State private var maxCount: Int = 1
    @State private var totalReviews: Int = 0
    @State private var weeksToShow: Int = 26
    @State private var isExpanding = false
    @State private var gridCache = HeatmapGridCache()

    var compactHeight: CGFloat? = nil

    private var isCompact: Bool {
        compactHeight != nil
    }

    private var cellSpacing: CGFloat {
        isCompact ? 1.25 : 2
    }

    private var weekdayLabelWidth: CGFloat {
        isCompact ? 16 : 22
    }

    private var cellSize: CGFloat {
        guard let compactHeight else { return 12 }
        let reservedHeight: CGFloat = 92
        let availableGridHeight = max(56, compactHeight - reservedHeight)
        let computed = (availableGridHeight - (cellSpacing * 6)) / 7
        return min(12, max(7, computed))
    }

    // MARK: - Derived Computed Properties (sync, over snapshot)

    private var currentStreak: Int {
        DayStreak.count(totals: visibleData, window: max(1, selectedDateRange))
    }

    private var reviewsThisWeek: Int {
        let today = Calendar.current.startOfDay(for: Date())
        let weekday = Calendar.current.component(.weekday, from: today)
        let daysFromMonday = (weekday + 5) % 7
        return (0...daysFromMonday).reduce(0) { $0 + (visibleData[-$1] ?? 0) }
    }

    private var reviewsThisMonth: Int {
        let day = Calendar.current.component(.day, from: Date())
        return (0..<day).reduce(0) { $0 + (visibleData[-$1] ?? 0) }
    }

    // MARK: - Grid Data

    private var grid: HeatmapGrid {
        gridCache.grid(weekCount: weeksToShow, counts: visibleData)
    }

    // MARK: - Body

    public var body: some View {
        AmgiCard(
            background: .surface,
            shadow: palette.shadows.sm,
            cornerRadius: AmgiRadius.inset,
            contentInsets: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        ) {
            heatmapContent()
        }
        .task {
            await initializeLoadingManager()
            await refreshFromManager()
        }
    }
}

private extension HeatmapChartOptimized {
    func heatmapContent() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text("Heatmap")
                    .amgiFont(.sectionHeading)
                    .foregroundStyle(palette.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Range picker and streak stack instead of sharing the title's
                // row — on narrow widths all three together truncate the title.
                VStack(alignment: .trailing, spacing: AmgiSpacing.xxs) {
                    #if !os(watchOS)
                    if !isCompact {
                        Menu {
                            ForEach([30, 90, 180, 365, 730], id: \.self) { days in
                                Button(dateRangeLabel(days)) {
                                    Task {
                                        await updateDateRange(days)
                                    }
                                }
                            }
                        } label: {
                            Label(dateRangeLabel(selectedDateRange), systemImage: "line.horizontal.3.decrease.circle")
                                .amgiFont(.caption)
                                .foregroundStyle(palette.accent)
                        }
                    }
                    #endif

                    if currentStreak > 0 {
                        Label("\(currentStreak)-day streak", systemImage: "flame.fill")
                            .amgiFont(.micro)
                            .foregroundStyle(palette.warning)
                    }
                }
            }

            if visibleData.isEmpty {
                Text("No reviews yet")
                    .foregroundStyle(palette.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: isCompact ? 72 : 100)
            } else {
                if !isCompact {
                    HStack(spacing: 16) {
                        summaryItem(value: "\(totalReviews)", label: "Total")
                        summaryItem(value: "\(reviewsThisMonth)", label: "This month")
                        summaryItem(value: "\(reviewsThisWeek)", label: "This week")
                        summaryItem(value: "\(visibleData[0] ?? 0)", label: "Today")
                    }
                }

                ScrollViewReader { scrollProxy in
                    ScrollView(.horizontal, showsIndicators: !isCompact) {
                        VStack(alignment: .leading, spacing: 0) {
                            monthHeaderView()
                            gridView()
                        }
                        .id("heatmapContent")
                    }
                    .defaultScrollAnchor(.trailing)
                    .onScrollGeometryChange(
                        for: CGFloat.self,
                        of: { geometry in geometry.contentOffset.x },
                        action: { _, newValue in
                            handleScroll(offset: newValue)
                        }
                    )
                }

                legendView()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - View Components
}

private extension HeatmapChartOptimized {
    func monthHeaderView() -> some View {
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

    func gridView() -> some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(spacing: cellSpacing) {
                ForEach(0..<7, id: \.self) { day in
                    Text(weekdayLabel(day))
                        .font(.system(size: 8))
                        .foregroundStyle(palette.textSecondary)
                        .frame(width: weekdayLabelWidth, height: cellSize)
                }
            }

            HStack(spacing: cellSpacing) {
                ForEach(grid.weeks) { week in
                    VStack(spacing: cellSpacing) {
                        ForEach(week.days) { day in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(
                                    day.isFuture
                                        ? Color.clear
                                        : HeatmapColorRamp.color(
                                            count: day.count,
                                            maxCount: maxCount,
                                            palette: palette
                                        )
                                )
                                .frame(width: cellSize, height: cellSize)
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Review activity")
        .accessibilityValue(heatmapSummary)
    }

    var heatmapSummary: String {
        let days = visibleData.values.count(where: { $0 > 0 })
        return "\(ChartSpeech.count(totalReviews, "review")) over \(dateRangeLabel(selectedDateRange)), "
            + "on \(ChartSpeech.count(days, "day")). Busiest day \(ChartSpeech.count(maxCount, "review"))."
    }

    func legendView() -> some View {
        HStack(spacing: isCompact ? 3 : 4) {
            Text("Less").amgiFont(.micro).foregroundStyle(palette.textSecondary)
            ForEach(Array(HeatmapColorRamp.legendColors(palette: palette).enumerated()), id: \.offset) { _, color in
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: cellSize, height: cellSize)
            }
            Text("More").amgiFont(.micro).foregroundStyle(palette.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .accessibilityHidden(true)
    }

    // MARK: - Helpers

    func summaryItem(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .amgiFont(.bodyEmphasis)
                .monospacedDigit()
            Text(label)
                .amgiFont(.micro)
                .foregroundStyle(palette.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }

    func weekdayLabel(_ index: Int) -> String {
        switch index {
        case 1: "M"
        case 3: "W"
        case 5: "F"
        default: ""
        }
    }

    func dateRangeLabel(_ days: Int) -> String {
        switch days {
        case 30: return "Last 30 days"
        case 90: return "Last 90 days"
        case 180: return "Last 6 months"
        case 365: return "Last 1 year"
        case 730: return "Last 2 years"
        default: return "\(days) days"
        }
    }

    // MARK: - Async Snapshot Helper

    func refreshFromManager() async {
        guard let manager = loadingManager else { return }
        let snapshot = await manager.getVisibleData()
        var nextVisible = [Int: Int](minimumCapacity: snapshot.count)
        var nextTotal = 0
        var nextMax = 1
        for (offset, review) in snapshot {
            nextVisible[offset] = review.total
            nextTotal += review.total
            nextMax = Swift.max(nextMax, review.total)
        }
        visibleData = nextVisible
        totalReviews = nextTotal
        maxCount = nextMax
        weeksToShow = Self.weekCount(for: nextVisible)
    }

    static func weekCount(for data: [Int: Int]) -> Int {
        guard let minOffset = data.keys.min() else { return 26 }
        return max((Swift.abs(minOffset) + 7) / 7 + 1, 26)
    }

    // MARK: - State Management

    func initializeLoadingManager() async {
        let manager = HeatmapLoadingManager()
        await manager.loadAllData(reviews)
        self.loadingManager = manager
    }

    func updateDateRange(_ days: Int) async {
        selectedDateRange = days
        guard let manager = loadingManager else { return }
        await manager.setDateRange(days: days)
        await refreshFromManager()
    }

    func handleScroll(offset: CGFloat) {
        let scrollThreshold: CGFloat = 100
        let contentWidth = CGFloat(weeksToShow) * (cellSize + cellSpacing)
        let isNearEnd = contentWidth - offset < scrollThreshold

        guard isNearEnd, !isExpanding else { return }
        isExpanding = true
        Task {
            await loadingManager?.expandDateRange()
            await refreshFromManager()
            isExpanding = false
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    HeatmapChartOptimized(reviews: .sampleYear)
        .padding()
}
#endif
