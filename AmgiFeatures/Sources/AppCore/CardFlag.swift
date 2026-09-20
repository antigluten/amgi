//
//  CardFlag.swift
//  AppCore
//
//  Created by Vladimir Gusev on 08.08.2026.
//

public import SwiftUI

/// Anki packs the flag into the low three bits of a card's `flags` field.
public enum CardFlag {
    /// `0` is "no flag"; 1–7 are the seven colours, in Anki's order.
    public static let all: [UInt32] = [0, 1, 2, 3, 4, 5, 6, 7]

    public static func name(_ value: UInt32) -> String {
        switch value & 0b111 {
        case 1: return "Red"
        case 2: return "Orange"
        case 3: return "Green"
        case 4: return "Blue"
        case 5: return "Pink"
        case 6: return "Cyan"
        case 7: return "Purple"
        default: return "No Flag"
        }
    }

    public static func color(_ value: UInt32) -> Color {
        switch value & 0b111 {
        case 1: return .red
        case 2: return .orange
        case 3: return .green
        case 4: return .blue
        case 5: return .pink
        case 6: return .cyan
        case 7: return .purple
        default: return .secondary
        }
    }

    public static func symbol(_ value: UInt32) -> String {
        value & 0b111 == 0 ? "flag.slash.fill" : "flag.fill"
    }
}
