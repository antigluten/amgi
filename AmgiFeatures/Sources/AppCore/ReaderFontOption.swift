//
//  ReaderFontOption.swift
//  AppCore
//
//  Created by Vladimir Gusev on 05.05.2026.
//

import Foundation

public enum ReaderFontOption: String, CaseIterable, Identifiable, Sendable {
    case system
    case appleSDGothicNeo = "Apple SD Gothic Neo"
    case appleGothic = "AppleGothic"
    case nanumMyeongjo = "NanumMyeongjo"
    case nanumGothic = "NanumGothic"
    case sarasaMonoK = "Sarasa Mono K"
    case hiraginoMincho = "Hiragino Mincho ProN"
    case hiraginoKakuGothic = "Hiragino Kaku Gothic ProN"

    public static let defaultValue = ReaderFontOption.system.rawValue

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .system: return "System"
        case .appleSDGothicNeo: return "Apple SD Gothic Neo"
        case .appleGothic: return "AppleGothic"
        case .nanumMyeongjo: return "Nanum Myeongjo (serif)"
        case .nanumGothic: return "Nanum Gothic"
        case .sarasaMonoK: return "Sarasa Mono K (mono)"
        case .hiraginoMincho: return "Hiragino Mincho ProN"
        case .hiraginoKakuGothic: return "Hiragino Kaku Gothic ProN"
        }
    }

    public var cssFontFamily: String {
        let koreanFallback = "\"Apple SD Gothic Neo\", \"AppleGothic\""
        switch self {
        case .system:
            return "-apple-system, BlinkMacSystemFont, \(koreanFallback), sans-serif"
        case .appleSDGothicNeo, .appleGothic, .nanumGothic:
            return "\"\(rawValue)\", \(koreanFallback), sans-serif"
        case .nanumMyeongjo:
            return "\"\(rawValue)\", \(koreanFallback), serif"
        case .sarasaMonoK:
            return "\"\(rawValue)\", \(koreanFallback), monospace"
        case .hiraginoMincho:
            return "\"\(rawValue)\", \(koreanFallback), serif"
        case .hiraginoKakuGothic:
            return "\"\(rawValue)\", \(koreanFallback), sans-serif"
        }
    }

    public static func resolved(_ rawValue: String) -> ReaderFontOption {
        ReaderFontOption(rawValue: rawValue) ?? .system
    }
}
