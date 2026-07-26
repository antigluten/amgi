// Mirror enums for `Anki_DeckConfig_DeckConfig.Config.*`. Cases match
// the proto names so migration is mechanical; raw integer values match
// the wire format so the bridge can convert with a 1:1 switch.
//
// Unlike the SwiftProtobuf-generated enums these have no
// `UNRECOGNIZED(Int)` case — exhaustive switches in the bridge stay
// compile-error guarded if upstream adds a case (the build will fail
// in `AnkiProtoBridge` until the new case is added here).

public enum NewCardInsertOrder: Int, Sendable, Hashable, Codable, CaseIterable {
    case due = 0
    case random = 1
}

public enum NewCardGatherPriority: Int, Sendable, Hashable, Codable, CaseIterable {
    case deck = 0
    case lowestPosition = 1
    case highestPosition = 2
    case randomNotes = 3
    case randomCards = 4
    case deckThenRandomNotes = 5
}

public enum NewCardSortOrder: Int, Sendable, Hashable, Codable, CaseIterable {
    case template = 0
    case noSort = 1
    case templateThenRandom = 2
    case randomNoteThenTemplate = 3
    case randomCard = 4
}

public enum ReviewCardOrder: Int, Sendable, Hashable, Codable, CaseIterable {
    case day = 0
    case dayThenDeck = 1
    case deckThenDay = 2
    case intervalsAscending = 3
    case intervalsDescending = 4
    case easeAscending = 5
    case easeDescending = 6
    case retrievabilityAscending = 7
    case random = 8
    case added = 9
    case reverseAdded = 10
    case retrievabilityDescending = 11
}

public enum ReviewMix: Int, Sendable, Hashable, Codable, CaseIterable {
    case mixWithReviews = 0
    case afterReviews = 1
    case beforeReviews = 2
}

public enum LeechAction: Int, Sendable, Hashable, Codable, CaseIterable {
    case suspend = 0
    case tagOnly = 1
}

public enum AnswerAction: Int, Sendable, Hashable, Codable, CaseIterable {
    case buryCard = 0
    case answerAgain = 1
    case answerGood = 2
    case answerHard = 3
    case showReminder = 4
}

public enum QuestionAction: Int, Sendable, Hashable, Codable, CaseIterable {
    case showAnswer = 0
    case showReminder = 1
}

/// Mirror for the top-level `Anki_DeckConfig_UpdateDeckConfigsMode`.
public enum UpdateDeckConfigsMode: Int, Sendable, Hashable, Codable, CaseIterable {
    case normal = 0
    case applyToChildren = 1
    case computeAllParams = 2
}
