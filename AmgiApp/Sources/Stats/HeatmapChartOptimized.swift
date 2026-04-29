import SwiftUI
import AmgiTheme
import AnkiProto

/// Optimized heatmap with incremental loading.
/// - Initially loads 6 months of data.
/// - Loads more when scrolling to edges.
/// - Configurable via the date range menu.
struct HeatmapChartOptimized: View {
    let reviews: Anki_Stats_GraphsResponse.ReviewCountsAndTimes

    @Environment(\.palette) private var palette
    @State private var loadingManager: HeatmapLoadingManager?
    @State private var shouldShowLoadingIndicator = false
    @State private var scrollPosition: CGFloat = 0
    @State private var selectedDateRange: Int = 180

    // Snapshotted from actor after each mutation. Other derived values are
    // computed from this dictionary inline (cheap sync transforms).
    @State private var visibleData: [Int: Int] = [:]
    @State private var maxCount: Int = 1
    @State private var totalReviews: Int = 0

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
        var streak = 0
        var offset = 0
        if visibleData[0] == nil || visibleData[0] == 0 {
            offset = -1
        }
        while let count = visibleData[offset], count > 0 {
            streak += 1
            offset -= 1
        }
        return streak
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

    private var weeksToShow: Int {
        guard let minOffset = visibleData.keys.min() else { return 26 }
        let totalDays = Swift.abs(minOffset) + 7
        let weeksNeeded = totalDays / 7 + 1
        return max(weeksNeeded, 26)
    }

    private var weeks: [[Date]] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let startDate = calendar.date(byAdding: .weekOfYear, value: -(weeksToShow - 1), to: today)!
        let startOfWeek = calendar.date(
            from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: startDate)
        )!

        var result: [[Date]] = []
        var current = startOfWeek
        while current <= today {
            var week: [Date] = []
            for dayOff in 0..<7 {
                week.append(calendar.date(byAdding: .day, value: dayOff, to: current)!)
            }
            result.append(week)
            current = calendar.date(byAdding: .weekOfYear, value: 1, to: current)!
        }
        return result
    }

    private var monthLabels: [(String, Int)] {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM"
        var labels: [(String, Int)] = []
        var lastMonth = -1
        for (weekIdx, week) in weeks.enumerated() {
            let month = Calendar.current.component(.month, from: week[0])
            if month != lastMonth {
                labels.append((fmt.string(from: week[0]), weekIdx))
                lastMonth = month
            }
        }
        return labels
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Reviews")
                    .amgiFont(.sectionHeading)
                    .foregroundStyle(palette.textPrimary)
                Spacer()

                // Date range picker (when not compact)
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

                if currentStreak > 0 {
                    Label("\(currentStreak)-day streak", systemImage: "flame.fill")
                        .amgiFont(.captionBold)
                        .foregroundStyle(.orange)
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

                // Scroll view with edge detection for loading more
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
        .padding(isCompact ? 10 : 16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(palette.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(palette.border.opacity(0.32), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 12, y: 4)
        .task {
            await initializeLoadingManager()
            await refreshFromManager()
        }
    }

    // MARK: - View Components

    private func monthHeaderView() -> some View {
        HStack(spacing: 0) {
            Spacer().frame(width: weekdayLabelWidth)
            ForEach(0..<weeks.count, id: \.self) { weekIdx in
                if let label = monthLabels.first(where: { $0.1 == weekIdx }) {
                    Text(label.0)
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

    private func gridView() -> some View {
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
                ForEach(0..<weeks.count, id: \.self) { weekIdx in
                    VStack(spacing: cellSpacing) {
                        ForEach(0..<7, id: \.self) { dayIdx in
                            let date = weeks[weekIdx][dayIdx]
                            let offset = dayOffset(for: date)
                            let count = visibleData[offset] ?? 0
                            let isFuture = date > Date()

                            RoundedRectangle(cornerRadius: 2)
                                .fill(isFuture ? Color.clear : heatColor(count: count))
                                .frame(width: cellSize, height: cellSize)
                        }
                    }
                }
            }
        }
    }

    private func legendView() -> some View {
        HStack(spacing: isCompact ? 3 : 4) {
            Spacer()
            Text("Less").amgiFont(.micro).foregroundStyle(palette.textSecondary)
            ForEach([0.0, 0.25, 0.5, 0.75, 1.0], id: \.self) { intensity in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.green.opacity(max(0.1, intensity)))
                    .frame(width: cellSize, height: cellSize)
            }
            Text("More").amgiFont(.micro).foregroundStyle(palette.textSecondary)
        }
    }

    // MARK: - Helpers

    private func summaryItem(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline.weight(.semibold).monospacedDigit())
            Text(label)
                .amgiFont(.micro)
                .foregroundStyle(palette.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func weekdayLabel(_ index: Int) -> String {
        switch index {
        case 1: "M"
        case 3: "W"
        case 5: "F"
        default: ""
        }
    }

    private func heatColor(count: Int) -> Color {
        if count == 0 { return Color(.systemGray6) }
        let intensity = min(1.0, Double(count) / Double(max(maxCount, 1)))
        return .green.opacity(max(0.2, intensity))
    }

    private func dayOffset(for date: Date) -> Int {
        let today = Calendar.current.startOfDay(for: Date())
        let target = Calendar.current.startOfDay(for: date)
        return Calendar.current.dateComponents([.day], from: today, to: target).day ?? 0
    }

    private func dateRangeLabel(_ days: Int) -> String {
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

    /// Reads the actor's current visible data and snapshots it into @State.
    /// Called on the @MainActor (view) after every actor mutation.
    private func refreshFromManager() async {
        guard let manager = loadingManager else { return }
        let snapshot = await manager.getVisibleData()
        var nextVisible: [Int: Int] = [:]
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
    }

    // MARK: - State Management

    private func initializeLoadingManager() async {
        let manager = HeatmapLoadingManager()
        await manager.loadAllData(reviews)
        self.loadingManager = manager
    }

    private func updateDateRange(_ days: Int) async {
        selectedDateRange = days
        guard let manager = loadingManager else { return }
        await manager.setDateRange(days: days)
        await refreshFromManager()
    }

    private func handleScroll(offset: CGFloat) {
        let scrollThreshold: CGFloat = 100
        let contentWidth = CGFloat(weeksToShow) * (cellSize + cellSpacing)
        let isNearEnd = contentWidth - offset < scrollThreshold

        if isNearEnd {
            Task {
                await loadingManager?.expandDateRange()
                await refreshFromManager()
            }
        }
    }
}
