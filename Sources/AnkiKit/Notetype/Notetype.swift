public import Foundation

/// Mirror for `Anki_Notetypes_Notetype`. Carries identity + bookkeeping
/// fields, the inner `Config` payload, the field schema, and the card
/// templates.
///
/// Coexists with the lightweight `NotetypeInfo` summary type; the
/// full mirror is what consumers like `DeckTemplateListView` need.
public struct Notetype: Sendable, Hashable, Identifiable {
    public var id: NotetypeID
    public var name: String
    public var mtimeSecs: Int64
    public var usn: Int32
    public var config: Config
    public var fields: [Field]
    public var templates: [Template]

    public init(
        id: NotetypeID = NotetypeID(0),
        name: String = "",
        mtimeSecs: Int64 = 0,
        usn: Int32 = 0,
        config: Config = Config(),
        fields: [Field] = [],
        templates: [Template] = []
    ) {
        self.id = id
        self.name = name
        self.mtimeSecs = mtimeSecs
        self.usn = usn
        self.config = config
        self.fields = fields
        self.templates = templates
    }

    public enum Kind: Int, Sendable, Hashable, Codable, CaseIterable {
        case normal = 0
        case cloze = 1
    }

    public struct Config: Sendable, Hashable {
        public var kind: Kind
        public var sortFieldIdx: Int
        public var css: String
        /// Stored separately upstream; preserved for round-trip safety.
        public var targetDeckIDUnused: Int64
        public var latexPre: String
        public var latexPost: String
        public var latexSvg: Bool
        public var reqs: [CardRequirement]
        public var originalStockKind: OriginalStockKind
        /// Source-collection id for imported notetypes (Anki 23.10+).
        public var originalID: Int64?
        /// Add-on/JSON blob the backend round-trips. Passed through as-is.
        public var other: Data

        public init(
            kind: Kind = .normal,
            sortFieldIdx: Int = 0,
            css: String = "",
            targetDeckIDUnused: Int64 = 0,
            latexPre: String = "",
            latexPost: String = "",
            latexSvg: Bool = false,
            reqs: [CardRequirement] = [],
            originalStockKind: OriginalStockKind = .unknown,
            originalID: Int64? = nil,
            other: Data = Data()
        ) {
            self.kind = kind
            self.sortFieldIdx = sortFieldIdx
            self.css = css
            self.targetDeckIDUnused = targetDeckIDUnused
            self.latexPre = latexPre
            self.latexPost = latexPost
            self.latexSvg = latexSvg
            self.reqs = reqs
            self.originalStockKind = originalStockKind
            self.originalID = originalID
            self.other = other
        }

        /// Mirror for `Anki_Notetypes_StockNotetype.OriginalStockKind`.
        /// Cases match the upstream enum so the wire integer values
        /// align 1:1.
        public enum OriginalStockKind: Int, Sendable, Hashable, Codable, CaseIterable {
            case unknown = 0
            case basic = 1
            case basicAndReversed = 2
            case basicOptionalReversed = 3
            case basicTyping = 4
            case cloze = 5
            case imageOcclusion = 6
        }

        public struct CardRequirement: Sendable, Hashable {
            public var cardOrd: Int
            public var kind: Kind
            public var fieldOrds: [Int]

            public init(cardOrd: Int, kind: Kind, fieldOrds: [Int]) {
                self.cardOrd = cardOrd
                self.kind = kind
                self.fieldOrds = fieldOrds
            }

            public enum Kind: Int, Sendable, Hashable, Codable, CaseIterable {
                case none = 0
                case any = 1
                case all = 2
            }
        }
    }

    public struct Field: Sendable, Hashable {
        /// Wire wrapper is `optional UInt32`. `nil` means "unset"; the
        /// backend assigns one on save.
        public var ord: Int?
        public var name: String
        public var config: Config

        public init(ord: Int? = nil, name: String = "", config: Config = Config()) {
            self.ord = ord
            self.name = name
            self.config = config
        }

        public struct Config: Sendable, Hashable {
            public var sticky: Bool
            public var rtl: Bool
            public var fontName: String
            public var fontSize: Int
            public var description: String
            public var plainText: Bool
            public var collapsed: Bool
            public var excludeFromSearch: Bool
            /// Source-collection field id for merge-on-import (Anki 23.10+).
            public var id: Int64?
            /// Stable identifier for required fields.
            public var tag: Int?
            public var preventDeletion: Bool
            public var other: Data

            public init(
                sticky: Bool = false,
                rtl: Bool = false,
                fontName: String = "",
                fontSize: Int = 0,
                description: String = "",
                plainText: Bool = false,
                collapsed: Bool = false,
                excludeFromSearch: Bool = false,
                id: Int64? = nil,
                tag: Int? = nil,
                preventDeletion: Bool = false,
                other: Data = Data()
            ) {
                self.sticky = sticky
                self.rtl = rtl
                self.fontName = fontName
                self.fontSize = fontSize
                self.description = description
                self.plainText = plainText
                self.collapsed = collapsed
                self.excludeFromSearch = excludeFromSearch
                self.id = id
                self.tag = tag
                self.preventDeletion = preventDeletion
                self.other = other
            }
        }
    }

    public struct Template: Sendable, Hashable {
        public var ord: Int?
        public var name: String
        public var mtimeSecs: Int64
        public var usn: Int32
        public var config: Config

        public init(
            ord: Int? = nil,
            name: String = "",
            mtimeSecs: Int64 = 0,
            usn: Int32 = 0,
            config: Config = Config()
        ) {
            self.ord = ord
            self.name = name
            self.mtimeSecs = mtimeSecs
            self.usn = usn
            self.config = config
        }

        public struct Config: Sendable, Hashable {
            public var qFormat: String
            public var aFormat: String
            public var qFormatBrowser: String
            public var aFormatBrowser: String
            public var targetDeckID: DeckID
            public var browserFontName: String
            public var browserFontSize: Int
            /// Source-collection template id for merge-on-import.
            public var id: Int64?
            public var other: Data

            public init(
                qFormat: String = "",
                aFormat: String = "",
                qFormatBrowser: String = "",
                aFormatBrowser: String = "",
                targetDeckID: DeckID = DeckID(0),
                browserFontName: String = "",
                browserFontSize: Int = 0,
                id: Int64? = nil,
                other: Data = Data()
            ) {
                self.qFormat = qFormat
                self.aFormat = aFormat
                self.qFormatBrowser = qFormatBrowser
                self.aFormatBrowser = aFormatBrowser
                self.targetDeckID = targetDeckID
                self.browserFontName = browserFontName
                self.browserFontSize = browserFontSize
                self.id = id
                self.other = other
            }
        }
    }
}

/// Mirror for `Anki_Notetypes_NotetypeNameId` — the lightweight
/// "all notetype names" listing used by pickers.
public struct NotetypeNameId: Sendable, Hashable, Identifiable {
    public var id: NotetypeID
    public var name: String

    public init(id: NotetypeID, name: String) {
        self.id = id
        self.name = name
    }
}
