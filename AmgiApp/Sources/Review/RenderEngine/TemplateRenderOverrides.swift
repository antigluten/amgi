import AmgiCardWeb
import AnkiKit
import Foundation

/// Local-only per-template render-engine overrides (R11), persisted as a JSON
/// `[String: String]` payload — `"<mid>:<ord>"` → `CardRenderEngine` raw —
/// inside a single appStorage key. Never written to the Anki collection, so
/// nothing syncs or conflicts. Pure helpers over the raw payload string; the
/// `@Shared(.appStorage)` wiring lives at the call sites.
enum TemplateRenderOverrides {
    static func key(mid: NotetypeID, ord: Int) -> String {
        "\(mid.rawValue):\(ord)"
    }

    static func engine(for mid: NotetypeID, ord: Int, in raw: String) -> CardRenderEngine? {
        decode(raw)[key(mid: mid, ord: ord)]
    }

    /// Returns the payload with the override set, or removed when `engine`
    /// is nil.
    static func setting(_ engine: CardRenderEngine?, mid: NotetypeID, ord: Int, in raw: String) -> String {
        var dict = decode(raw)
        dict[key(mid: mid, ord: ord)] = engine
        return encode(dict)
    }

    static func removing(key: String, in raw: String) -> String {
        var dict = decode(raw)
        dict[key] = nil
        return encode(dict)
    }

    /// All overrides, sorted by key for stable display.
    static func entries(in raw: String) -> [(key: String, engine: CardRenderEngine)] {
        decode(raw).sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
    }

    // MARK: - Codec

    static func decode(_ raw: String) -> [String: CardRenderEngine] {
        guard let data = raw.data(using: .utf8),
              let dict = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }
        return dict.compactMapValues(CardRenderEngine.init(rawValue:))
    }

    static func encode(_ dict: [String: CardRenderEngine]) -> String {
        let plain = dict.mapValues(\.rawValue)
        guard let data = try? JSONEncoder().encode(plain) else { return "{}" }
        return String(decoding: data, as: UTF8.self)
    }
}
