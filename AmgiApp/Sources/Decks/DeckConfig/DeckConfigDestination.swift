import CasePaths

/// One source of truth for every modal axis on the deck-options screen.
/// Sheet (the FSRS simulator) and alert (save error / FSRS error / preset
/// error / create-preset / rename-preset / delete-confirm) collapse into a
/// single `Destination?`, mirroring the pattern in `DeckDetailView`.
@CasePathable
enum DeckConfigDestination {
    case alert(DeckConfigAlert)
    case sheet(DeckConfigSheet)
}

@CasePathable
enum DeckConfigAlert {
    case saveFailed(String)
    case fsrsError(String)
    case presetError(String)
    case createPreset
    case renamePreset
    case deletePresetConfirm
}

enum DeckConfigSheet: Identifiable {
    case simulator(FsrsSimulatorContext)

    var id: String {
        switch self {
        case .simulator(let context): "simulator-\(context.id)"
        }
    }
}
