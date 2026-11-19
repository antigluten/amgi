//
//  PeriodPicker.swift
//  StatsCharts
//
//  Created by Vladimir Gusev on 30.03.2026.
//

import SwiftUI

public enum StatsPeriod: String, CaseIterable, Sendable {
    case day = "Today"
    case week = "7 Days"
    case month = "1 Month"
    case threeMonths = "3 Months"
    case year = "1 Year"
    case all = "All Time"

    public var days: Int {
        switch self {
        case .day: 1
        case .week: 7
        case .month: 31
        case .threeMonths: 92
        case .year: 365
        case .all: 36500
        }
    }

    /// The period's display name. `rawValue` stays the stable English
    /// identifier; this is what the menu shows.
    public var title: String {
        switch self {
        case .day: String(localized: "Today", bundle: .module)
        case .week: String(localized: "7 Days", bundle: .module)
        case .month: String(localized: "1 Month", bundle: .module)
        case .threeMonths: String(localized: "3 Months", bundle: .module)
        case .year: String(localized: "1 Year", bundle: .module)
        case .all: String(localized: "All Time", bundle: .module)
        }
    }

    public var shortLabel: String {
        switch self {
        case .day: "1D"
        case .week: "7D"
        case .month: "1M"
        case .threeMonths: "3M"
        case .year: "1Y"
        case .all: String(localized: "All", bundle: .module)
        }
    }
}
