import Foundation

/// Font family the chapter reader injects via CSS. Korean-first list: the
/// system Korean face (Apple SD Gothic Neo) is always present on iOS;
/// Sarasa Mono K, Nanum Myeongjo, and Nanum Gothic are common community
/// fonts that may be installed by the user — we list them here and rely on
/// the CSS fallback chain to substitute when they're absent.
///
/// The raw value is what gets persisted in `ReaderPreferences.Keys.selectedFont`.
enum ReaderFontOption: String, CaseIterable, Identifiable, Sendable {
    case system
    case appleSDGothicNeo = "Apple SD Gothic Neo"
    case appleGothic = "AppleGothic"
    case nanumMyeongjo = "NanumMyeongjo"
    case nanumGothic = "NanumGothic"
    case sarasaMonoK = "Sarasa Mono K"
    case hiraginoMincho = "Hiragino Mincho ProN"
    case hiraginoKakuGothic = "Hiragino Kaku Gothic ProN"

    static let defaultValue = ReaderFontOption.system.rawValue

    var id: String { rawValue }

    var title: String {
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

    /// CSS `font-family` value. Each option drops to a Korean-aware
    /// fallback so that a missing custom font still renders Hangul
    /// correctly rather than tofu.
    var cssFontFamily: String {
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

    static func resolved(_ rawValue: String) -> ReaderFontOption {
        ReaderFontOption(rawValue: rawValue) ?? .system
    }
}
