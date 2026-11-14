//
//  ChartAccessibility.swift
//  StatsCharts
//

import Foundation

enum ChartSpeech {
    static func day(_ offset: Int) -> String {
        switch offset {
        case 0: String(localized: "Today", bundle: .module)
        case 1: String(localized: "Tomorrow", bundle: .module)
        case -1: String(localized: "Yesterday", bundle: .module)
        case ..<0: String(localized: "\(-offset) days ago", bundle: .module)
        default: String(localized: "In \(offset) days", bundle: .module)
        }
    }

    /// What a spoken count is counting. A closed set rather than a noun
    /// string, so each phrase is one localizable entry with its own plural
    /// rules instead of an English "s" suffix.
    enum Noun {
        case card, review, day, press
    }

    static func count(_ value: Int, _ noun: Noun) -> String {
        switch noun {
        case .card: String(localized: "\(value) cards", bundle: .module)
        case .review: String(localized: "\(value) reviews", bundle: .module)
        case .day: String(localized: "\(value) days", bundle: .module)
        case .press: String(localized: "\(value) presses", bundle: .module)
        }
    }

    static func percent(_ value: Double) -> String {
        "\(Int(value.rounded()))%"
    }
}
