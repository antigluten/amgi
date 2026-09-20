//
//  ChartAccessibility.swift
//  StatsCharts
//

import Foundation

enum ChartSpeech {
    static func day(_ offset: Int) -> String {
        switch offset {
        case 0: "Today"
        case 1: "Tomorrow"
        case -1: "Yesterday"
        case ..<0: "\(-offset) days ago"
        default: "In \(offset) days"
        }
    }

    static func count(_ value: Int, _ noun: String) -> String {
        "\(value) \(noun)\(value == 1 ? "" : "s")"
    }

    static func percent(_ value: Double) -> String {
        "\(Int(value.rounded()))%"
    }
}
