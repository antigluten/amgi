//
//  DeckConfigDestination.swift
//  DecksFeature
//
//  Created by Vladimir Gusev on 14.05.2026.
//

import CasePaths

@CasePathable
enum DeckConfigDestination {
    case alert(DeckConfigAlert)
    case prompt(DeckConfigPrompt)
    case route(DeckConfigRoute)
}

@CasePathable
enum DeckConfigAlert {
    case saveFailed(String)
    case fsrsError(title: String, message: String)
    case presetError(String)
    case deletePresetConfirm
    case discardChanges
}

enum DeckConfigPrompt: String, Identifiable {
    case createPreset
    case renamePreset

    var id: String { rawValue }
}

enum DeckConfigRoute: Hashable {
    case simulator(FsrsSimulatorContext)
}
