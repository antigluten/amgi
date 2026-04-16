import SwiftUI

enum StatsPeriod: String, CaseIterable, Sendable {
    case day = "Today"
    case week = "7 Days"
    case month = "1 Month"
    case threeMonths = "3 Months"
    case year = "1 Year"
    case all = "All Time"

    var days: Int {
        switch self {
        case .day: 1
        case .week: 7
        case .month: 31
        case .threeMonths: 92
        case .year: 365
        case .all: 36500
        }
    }

    var shortLabel: String {
        switch self {
        case .day: "1D"
        case .week: "7D"
        case .month: "1M"
        case .threeMonths: "3M"
        case .year: "1Y"
        case .all: "All"
        }
    }
}
