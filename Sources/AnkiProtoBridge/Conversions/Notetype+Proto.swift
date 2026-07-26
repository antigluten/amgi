package import AnkiKit
package import AnkiProto

// MARK: - Notetype.Kind

package extension Anki_Notetypes_Notetype.Config.Kind {
    init(_ mirror: Notetype.Kind) {
        switch mirror {
        case .normal: self = .normal
        case .cloze: self = .cloze
        }
    }
}

package extension Notetype.Kind {
    init(_ proto: Anki_Notetypes_Notetype.Config.Kind) {
        switch proto {
        case .normal: self = .normal
        case .cloze: self = .cloze
        case .UNRECOGNIZED: self = .normal
        }
    }
}

// MARK: - CardRequirement.Kind

package extension Anki_Notetypes_Notetype.Config.CardRequirement.Kind {
    init(_ mirror: Notetype.Config.CardRequirement.Kind) {
        switch mirror {
        case .none: self = .none
        case .any: self = .any
        case .all: self = .all
        }
    }
}

package extension Notetype.Config.CardRequirement.Kind {
    init(_ proto: Anki_Notetypes_Notetype.Config.CardRequirement.Kind) {
        switch proto {
        case .none: self = .none
        case .any: self = .any
        case .all: self = .all
        case .UNRECOGNIZED: self = .none
        }
    }
}

// MARK: - OriginalStockKind

package extension Anki_Notetypes_StockNotetype.OriginalStockKind {
    init(_ mirror: Notetype.Config.OriginalStockKind) {
        switch mirror {
        case .unknown: self = .unknown
        case .basic: self = .basic
        case .basicAndReversed: self = .basicAndReversed
        case .basicOptionalReversed: self = .basicOptionalReversed
        case .basicTyping: self = .basicTyping
        case .cloze: self = .cloze
        case .imageOcclusion: self = .imageOcclusion
        }
    }
}

package extension Notetype.Config.OriginalStockKind {
    init(_ proto: Anki_Notetypes_StockNotetype.OriginalStockKind) {
        switch proto {
        case .unknown: self = .unknown
        case .basic: self = .basic
        case .basicAndReversed: self = .basicAndReversed
        case .basicOptionalReversed: self = .basicOptionalReversed
        case .basicTyping: self = .basicTyping
        case .cloze: self = .cloze
        case .imageOcclusion: self = .imageOcclusion
        case .UNRECOGNIZED: self = .unknown
        }
    }
}

// MARK: - CardRequirement

package extension Notetype.Config.CardRequirement {
    init(_ proto: Anki_Notetypes_Notetype.Config.CardRequirement) {
        self.init(
            cardOrd: Int(proto.cardOrd),
            kind: Kind(proto.kind),
            fieldOrds: proto.fieldOrds.map(Int.init)
        )
    }

    func toProto() -> Anki_Notetypes_Notetype.Config.CardRequirement {
        var proto = Anki_Notetypes_Notetype.Config.CardRequirement()
        proto.cardOrd = UInt32(max(0, cardOrd))
        proto.kind = .init(kind)
        proto.fieldOrds = fieldOrds.map { UInt32(max(0, $0)) }
        return proto
    }
}

// MARK: - Notetype.Config

package extension Notetype.Config {
    init(_ proto: Anki_Notetypes_Notetype.Config) {
        self.init(
            kind: Notetype.Kind(proto.kind),
            sortFieldIdx: Int(proto.sortFieldIdx),
            css: proto.css,
            targetDeckIDUnused: proto.targetDeckIDUnused,
            latexPre: proto.latexPre,
            latexPost: proto.latexPost,
            latexSvg: proto.latexSvg,
            reqs: proto.reqs.map { Notetype.Config.CardRequirement($0) },
            originalStockKind: OriginalStockKind(proto.originalStockKind),
            originalID: proto.hasOriginalID ? proto.originalID : nil,
            other: proto.other
        )
    }

    func toProto() -> Anki_Notetypes_Notetype.Config {
        var proto = Anki_Notetypes_Notetype.Config()
        proto.kind = .init(kind)
        proto.sortFieldIdx = UInt32(max(0, sortFieldIdx))
        proto.css = css
        proto.targetDeckIDUnused = targetDeckIDUnused
        proto.latexPre = latexPre
        proto.latexPost = latexPost
        proto.latexSvg = latexSvg
        proto.reqs = reqs.map { $0.toProto() }
        proto.originalStockKind = .init(originalStockKind)
        if let originalID { proto.originalID = originalID }
        proto.other = other
        return proto
    }
}

// MARK: - Notetype.Field.Config

package extension Notetype.Field.Config {
    init(_ proto: Anki_Notetypes_Notetype.Field.Config) {
        self.init(
            sticky: proto.sticky,
            rtl: proto.rtl,
            fontName: proto.fontName,
            fontSize: Int(proto.fontSize),
            description: proto.description_p,
            plainText: proto.plainText,
            collapsed: proto.collapsed,
            excludeFromSearch: proto.excludeFromSearch,
            id: proto.hasID ? proto.id : nil,
            tag: proto.hasTag ? Int(proto.tag) : nil,
            preventDeletion: proto.preventDeletion,
            other: proto.other
        )
    }

    func toProto() -> Anki_Notetypes_Notetype.Field.Config {
        var proto = Anki_Notetypes_Notetype.Field.Config()
        proto.sticky = sticky
        proto.rtl = rtl
        proto.fontName = fontName
        proto.fontSize = UInt32(max(0, fontSize))
        proto.description_p = description
        proto.plainText = plainText
        proto.collapsed = collapsed
        proto.excludeFromSearch = excludeFromSearch
        if let id { proto.id = id }
        if let tag { proto.tag = UInt32(max(0, tag)) }
        proto.preventDeletion = preventDeletion
        proto.other = other
        return proto
    }
}

// MARK: - Notetype.Field

package extension Notetype.Field {
    init(_ proto: Anki_Notetypes_Notetype.Field) {
        self.init(
            ord: proto.hasOrd ? Int(proto.ord.val) : nil,
            name: proto.name,
            config: Config(proto.config)
        )
    }

    func toProto() -> Anki_Notetypes_Notetype.Field {
        var proto = Anki_Notetypes_Notetype.Field()
        if let ord {
            var wrapper = Anki_Generic_UInt32()
            wrapper.val = UInt32(max(0, ord))
            proto.ord = wrapper
        }
        proto.name = name
        proto.config = config.toProto()
        return proto
    }
}

// MARK: - Notetype.Template.Config

package extension Notetype.Template.Config {
    init(_ proto: Anki_Notetypes_Notetype.Template.Config) {
        self.init(
            qFormat: proto.qFormat,
            aFormat: proto.aFormat,
            qFormatBrowser: proto.qFormatBrowser,
            aFormatBrowser: proto.aFormatBrowser,
            targetDeckID: DeckID(proto.targetDeckID),
            browserFontName: proto.browserFontName,
            browserFontSize: Int(proto.browserFontSize),
            id: proto.hasID ? proto.id : nil,
            other: proto.other
        )
    }

    func toProto() -> Anki_Notetypes_Notetype.Template.Config {
        var proto = Anki_Notetypes_Notetype.Template.Config()
        proto.qFormat = qFormat
        proto.aFormat = aFormat
        proto.qFormatBrowser = qFormatBrowser
        proto.aFormatBrowser = aFormatBrowser
        proto.targetDeckID = targetDeckID.rawValue
        proto.browserFontName = browserFontName
        proto.browserFontSize = UInt32(max(0, browserFontSize))
        if let id { proto.id = id }
        proto.other = other
        return proto
    }
}

// MARK: - Notetype.Template

package extension Notetype.Template {
    init(_ proto: Anki_Notetypes_Notetype.Template) {
        self.init(
            ord: proto.hasOrd ? Int(proto.ord.val) : nil,
            name: proto.name,
            mtimeSecs: proto.mtimeSecs,
            usn: proto.usn,
            config: Config(proto.config)
        )
    }

    func toProto() -> Anki_Notetypes_Notetype.Template {
        var proto = Anki_Notetypes_Notetype.Template()
        if let ord {
            var wrapper = Anki_Generic_UInt32()
            wrapper.val = UInt32(max(0, ord))
            proto.ord = wrapper
        }
        proto.name = name
        proto.mtimeSecs = mtimeSecs
        proto.usn = usn
        proto.config = config.toProto()
        return proto
    }
}

// MARK: - Notetype

package extension Notetype {
    init(_ proto: Anki_Notetypes_Notetype) {
        self.init(
            id: NotetypeID(proto.id),
            name: proto.name,
            mtimeSecs: proto.mtimeSecs,
            usn: proto.usn,
            config: Config(proto.config),
            fields: proto.fields.map { Field($0) },
            templates: proto.templates.map { Template($0) }
        )
    }
}

extension Notetype: BridgeDecodable {
    package typealias Proto = Anki_Notetypes_Notetype
}

package extension Notetype {
    func toProto() -> Anki_Notetypes_Notetype {
        var proto = Anki_Notetypes_Notetype()
        proto.id = id.rawValue
        proto.name = name
        proto.mtimeSecs = mtimeSecs
        proto.usn = usn
        proto.config = config.toProto()
        proto.fields = fields.map { $0.toProto() }
        proto.templates = templates.map { $0.toProto() }
        return proto
    }
}

// MARK: - NotetypeNameId

package extension NotetypeNameId {
    init(_ proto: Anki_Notetypes_NotetypeNameId) {
        self.init(id: NotetypeID(proto.id), name: proto.name)
    }
}
