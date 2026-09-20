//
//  TypedAnswer.swift
//  ReviewCore
//
//  Created by Vladimir Gusev on 20.08.2026.
//

import OSLog
import SwiftUI
import AppCore
#if canImport(UIKit)
import UIKit
#endif
import AmgiCardWeb
import AnkiClients
import AnkiKit
import AnkiServices
import Dependencies
import Foundation
// MARK: - Typed-answer state resolution

func resolveTypedAnswerState(
    for queued: QueuedReviewCard,
    frontHTML: String,
    notes: NotesService,
    notetypes: NotetypesService,
    cardRendering: CardRenderingService
) -> TypedAnswerState? {
    guard let placeholder = firstTypedAnswerPlaceholder(
        in: frontHTML,
        cardOrdinal: UInt32(max(0, queued.card.ord))
    ) else {
        return nil
    }

    do {
        let noteRecord = try notes.getNote(queued.card.nid)

        // Fetch per-field font/size config via service (keeps backend access inside AnkiServices).
        let fields = try notetypes.getNotetypeFields(noteRecord.mid)

        guard let field = fields.first(where: { $0.name == placeholder.fieldName }) else {
            // Field name not found — typed answer with empty expected
            return TypedAnswerState(
                placeholder: placeholder.rawToken,
                expected: "",
                combining: placeholder.combining,
                fontName: "-apple-system",
                fontSize: 18
            )
        }

        let fieldValues = noteRecord.flds.components(separatedBy: "\u{1f}")
        guard fieldValues.indices.contains(field.ordinal) else {
            return nil
        }

        var expected = fieldValues[field.ordinal]

        // Cloze typed-answer: extract the specific cloze ordinal's text
        if let clozeOrdinal = placeholder.clozeOrdinal {
            expected = try cardRendering.extractClozeForTyping(expected, clozeOrdinal)
        }

        return TypedAnswerState(
            placeholder: placeholder.rawToken,
            expected: expected,
            combining: placeholder.combining,
            fontName: field.fontName,
            fontSize: field.fontSize
        )
    } catch {
        Log.review.error("Typed answer resolution failed for card \(queued.card.id.rawValue): \(error)")
        return nil
    }
}

// MARK: - Placeholder parsing

private func firstTypedAnswerPlaceholder(in html: String, cardOrdinal: UInt32) -> TypedAnswerPlaceholder? {
    guard let regex = try? NSRegularExpression(pattern: #"\[\[type:(.+?)\]\]"#) else {
        return nil
    }
    let nsRange = NSRange(html.startIndex..., in: html)
    guard let match = regex.firstMatch(in: html, range: nsRange),
          let rawRange = Range(match.range(at: 0), in: html),
          let specRange = Range(match.range(at: 1), in: html)
    else {
        return nil
    }

    var spec = String(html[specRange])
    var combining = true
    var clozeOrdinal: UInt32?

    if spec.hasPrefix("cloze:") {
        spec.removeFirst("cloze:".count)
        clozeOrdinal = cardOrdinal + 1
    }
    if spec.hasPrefix("nc:") {
        spec.removeFirst("nc:".count)
        combining = false
    }

    guard !spec.isEmpty else { return nil }

    return TypedAnswerPlaceholder(
        rawToken: String(html[rawRange]),
        fieldName: spec,
        combining: combining,
        clozeOrdinal: clozeOrdinal
    )
}

func strippingTypedAnswerPlaceholders(from html: String) -> String {
    guard let regex = try? NSRegularExpression(pattern: #"\[\[type:.+?\]\]"#) else {
        return html
    }
    let range = NSRange(html.startIndex..., in: html)
    return regex.stringByReplacingMatches(in: html, range: range, withTemplate: "")
}
