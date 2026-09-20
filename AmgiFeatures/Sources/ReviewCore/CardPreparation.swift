//
//  CardPreparation.swift
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
public import AmgiCardWeb
import AnkiClients
public import AnkiKit
import AnkiServices
import Dependencies
import Foundation
// MARK: - Off-main card preparation
//
// These run inside `Task.detached`, so they are file-scope `nonisolated`
// functions that take the Sendable service facades explicitly rather than
// reaching through `self`. They produce a `Sendable PreparedCard` that
// `advanceToNextCard` assigns to `@Observable` state on the main actor.

/// Immutable, off-actor render result for one queued card.
struct PreparedCard: Sendable {
    let note: NoteRecord?
    let renderedFrontHTML: String
    let renderedBackHTML: String
    let cardCSS: String
    let typedAnswerState: TypedAnswerState?
    let frontHTML: String
    let resolvedMode: ResolvedRenderMode
    let resolvedByAuto: Bool
    let templateName: String?
    /// Freshly fetched notetype for the session cache; nil on cache hit
    /// or fetch failure.
    let notetype: Notetype?
}

/// Applies the R11 resolution order — template override → global preference
/// → complexity auto-detect — to one rendered card. `alwaysNative` still
/// yields `.html` when the card fails the simplicity check, so native
/// rendering is never lossy.
func resolveRenderMode(
    renderedFront: String,
    renderedBack: String,
    css: String,
    override: CardRenderEngine?,
    global: CardRenderEngine
) -> (mode: ResolvedRenderMode, byAuto: Bool) {
    let effective = override ?? global
    let simple = CardComplexity.isSimple(
        renderedFront: renderedFront,
        renderedBack: renderedBack,
        css: css
    )
    let wantNative = effective != .alwaysHTML && simple
    let mode: ResolvedRenderMode = wantNative
        ? .native(front: .parse(html: renderedFront), back: .parse(html: renderedBack))
        : .html
    return (mode, effective == .auto)
}

/// Reads the R11 engine preference + per-template override for one card.
/// UserDefaults is thread-safe, so this is callable from the off-actor
/// prepare path as well as main-actor re-resolution.
public func currentRenderEnginePreferences(mid: NotetypeID?, ord: Int) -> (global: CardRenderEngine, override: CardRenderEngine?) {
    let defaults = UserDefaults.standard
    let global = defaults.string(forKey: ReviewPreferences.Keys.cardRenderEngine)
        .flatMap(CardRenderEngine.init(rawValue:)) ?? .auto
    let overridesRaw = defaults.string(forKey: ReviewPreferences.Keys.templateRenderOverrides) ?? "{}"
    let override = mid.flatMap { TemplateRenderOverrides.engine(for: $0, ord: ord, in: overridesRaw) }
    return (global, override)
}

struct TypedAnswerPlaceholder {
    let rawToken: String
    let fieldName: String
    let combining: Bool
    let clozeOrdinal: UInt32?
}

func prepareCard(
    for queued: QueuedReviewCard,
    notes: NotesService,
    notetypes: NotetypesService,
    cardRendering: CardRenderingService,
    notetypesClient: NotetypesClient,
    notetypeCache: [NotetypeID: Notetype]
) async -> PreparedCard {
    let note: NoteRecord?
    do {
        note = try notes.getNote(queued.card.nid)
    } catch {
        Log.review.error("getNote failed: \(error)")
        note = nil
    }

    // Template name comes from the full notetype (cached per session);
    // fetch failure only costs the chip-row label.
    var fetchedNotetype: Notetype?
    var templateName: String?
    if let mid = note?.mid {
        let notetype: Notetype?
        if let cached = notetypeCache[mid] {
            notetype = cached
        } else {
            fetchedNotetype = try? await notetypesClient.get(mid)
            notetype = fetchedNotetype
        }
        let ord = Int(queued.card.ord)
        if let notetype, notetype.templates.indices.contains(ord) {
            templateName = notetype.templates[ord].name
        }
    }

    do {
        let rendered = try cardRendering.renderCard(queued.card.id)
        let typedState = resolveTypedAnswerState(
            for: queued,
            frontHTML: rendered.frontHTML,
            notes: notes,
            notetypes: notetypes,
            cardRendering: cardRendering
        )
        let prefs = currentRenderEnginePreferences(mid: note?.mid, ord: Int(queued.card.ord))
        let resolution = resolveRenderMode(
            renderedFront: rendered.frontHTML,
            renderedBack: rendered.backHTML,
            css: rendered.cardCSS,
            override: prefs.override,
            global: prefs.global
        )
        if case .html = resolution.mode {
            let issue = CardComplexity.complexityIssue(
                renderedFront: rendered.frontHTML,
                renderedBack: rendered.backHTML,
                css: rendered.cardCSS
            ) ?? "engine preference (global: \(prefs.global.rawValue), override: \(prefs.override?.rawValue ?? "none"))"
            Log.review.debug("card \(queued.card.id.rawValue) → HTML: \(issue)")
        }
        return PreparedCard(
            note: note,
            renderedFrontHTML: rendered.frontHTML,
            renderedBackHTML: rendered.backHTML,
            cardCSS: rendered.cardCSS,
            typedAnswerState: typedState,
            frontHTML: strippingTypedAnswerPlaceholders(from: rendered.frontHTML),
            resolvedMode: resolution.mode,
            resolvedByAuto: resolution.byAuto,
            templateName: templateName,
            notetype: fetchedNotetype
        )
    } catch {
        Log.review.error("Render failed for card \(queued.card.id.rawValue): \(error)")
        return PreparedCard(
            note: note,
            renderedFrontHTML: "<p>Error rendering card</p>",
            renderedBackHTML: "<p>Error rendering card</p>",
            cardCSS: "",
            typedAnswerState: nil,
            frontHTML: "<p>Error rendering card</p>",
            resolvedMode: .html,
            resolvedByAuto: false,
            templateName: templateName,
            notetype: fetchedNotetype
        )
    }
}

// MARK: - Typed-answer diff (off-actor)

/// Substitutes the `[[type:…]]` placeholder in a rendered back side with the
/// engine's answer diff. Nonisolated so the `compareAnswer` FFI call can run
/// off the main actor — it used to run inline in `revealAnswer()`, blocking
/// the main thread at the moment of the tap.
func typedAnswerBackHTML(
    state: TypedAnswerState,
    typedAnswer: String,
    renderedBackHTML: String,
    cardRendering: CardRenderingService
) -> String {
    guard renderedBackHTML.contains(state.placeholder) else {
        return renderedBackHTML
    }
    if state.expected.isEmpty {
        return renderedBackHTML.replacingOccurrences(of: state.placeholder, with: "")
    }
    do {
        let diff = try cardRendering.compareAnswer(state.expected, typedAnswer, state.combining)
        let wrapped = "<div style=\"font-family: '\(state.fontName)'; font-size: \(state.fontSize)px\">\(diff)</div>"
        return renderedBackHTML.replacingOccurrences(of: state.placeholder, with: wrapped)
    } catch {
        Log.review.error("compareAnswer failed: \(error)")
        return renderedBackHTML.replacingOccurrences(of: state.placeholder, with: "")
    }
}
