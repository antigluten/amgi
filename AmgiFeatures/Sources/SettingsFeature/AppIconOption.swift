//
//  AppIconOption.swift
//  SettingsFeature
//

#if os(iOS)
import Foundation

enum AppIconOption: CaseIterable, Identifiable {
    case standard, handwritten, deepTeal, midnight, celadon, persimmon

    var id: Self { self }

    var alternateName: String? {
        self == .standard ? nil : previewName
    }

    var previewName: String {
        switch self {
        case .standard: "Dojang"
        case .handwritten: "Handwritten"
        case .deepTeal: "DeepTeal"
        case .midnight: "Midnight"
        case .celadon: "Celadon"
        case .persimmon: "Persimmon"
        }
    }

    var displayName: String {
        switch self {
        case .standard: String(localized: "Dojang", bundle: .module)
        case .handwritten: String(localized: "Handwritten", bundle: .module)
        case .deepTeal: String(localized: "Deep Teal", bundle: .module)
        case .midnight: String(localized: "Midnight", bundle: .module)
        case .celadon: String(localized: "Celadon", bundle: .module)
        case .persimmon: String(localized: "Persimmon", bundle: .module)
        }
    }

    init(alternateName: String?) {
        self = Self.allCases.first { $0.alternateName == alternateName } ?? .standard
    }
}
#endif
