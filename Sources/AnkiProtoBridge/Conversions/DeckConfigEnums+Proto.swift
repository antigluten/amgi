package import AnkiKit
package import AnkiProto

// 1:1 mapping between AnkiKit enum mirrors and SwiftProtobuf enums.
// Switches are exhaustive — adding a case to either side is a compile
// error here. The proto's `UNRECOGNIZED(let raw)` tail maps to the
// proto default for the matching type so unknown wire values don't
// crash; the cluster's tests pin every known case.

package extension Anki_DeckConfig_DeckConfig.Config.NewCardInsertOrder {
    init(_ mirror: NewCardInsertOrder) {
        switch mirror {
        case .due: self = .due
        case .random: self = .random
        }
    }
}

package extension NewCardInsertOrder {
    init(_ proto: Anki_DeckConfig_DeckConfig.Config.NewCardInsertOrder) {
        switch proto {
        case .due: self = .due
        case .random: self = .random
        case .UNRECOGNIZED: self = .due
        }
    }
}

package extension Anki_DeckConfig_DeckConfig.Config.NewCardGatherPriority {
    init(_ mirror: NewCardGatherPriority) {
        switch mirror {
        case .deck: self = .deck
        case .lowestPosition: self = .lowestPosition
        case .highestPosition: self = .highestPosition
        case .randomNotes: self = .randomNotes
        case .randomCards: self = .randomCards
        case .deckThenRandomNotes: self = .deckThenRandomNotes
        }
    }
}

package extension NewCardGatherPriority {
    init(_ proto: Anki_DeckConfig_DeckConfig.Config.NewCardGatherPriority) {
        switch proto {
        case .deck: self = .deck
        case .lowestPosition: self = .lowestPosition
        case .highestPosition: self = .highestPosition
        case .randomNotes: self = .randomNotes
        case .randomCards: self = .randomCards
        case .deckThenRandomNotes: self = .deckThenRandomNotes
        case .UNRECOGNIZED: self = .deck
        }
    }
}

package extension Anki_DeckConfig_DeckConfig.Config.NewCardSortOrder {
    init(_ mirror: NewCardSortOrder) {
        switch mirror {
        case .template: self = .template
        case .noSort: self = .noSort
        case .templateThenRandom: self = .templateThenRandom
        case .randomNoteThenTemplate: self = .randomNoteThenTemplate
        case .randomCard: self = .randomCard
        }
    }
}

package extension NewCardSortOrder {
    init(_ proto: Anki_DeckConfig_DeckConfig.Config.NewCardSortOrder) {
        switch proto {
        case .template: self = .template
        case .noSort: self = .noSort
        case .templateThenRandom: self = .templateThenRandom
        case .randomNoteThenTemplate: self = .randomNoteThenTemplate
        case .randomCard: self = .randomCard
        case .UNRECOGNIZED: self = .template
        }
    }
}

package extension Anki_DeckConfig_DeckConfig.Config.ReviewCardOrder {
    init(_ mirror: ReviewCardOrder) {
        switch mirror {
        case .day: self = .day
        case .dayThenDeck: self = .dayThenDeck
        case .deckThenDay: self = .deckThenDay
        case .intervalsAscending: self = .intervalsAscending
        case .intervalsDescending: self = .intervalsDescending
        case .easeAscending: self = .easeAscending
        case .easeDescending: self = .easeDescending
        case .retrievabilityAscending: self = .retrievabilityAscending
        case .retrievabilityDescending: self = .retrievabilityDescending
        case .random: self = .random
        case .added: self = .added
        case .reverseAdded: self = .reverseAdded
        }
    }
}

package extension ReviewCardOrder {
    init(_ proto: Anki_DeckConfig_DeckConfig.Config.ReviewCardOrder) {
        switch proto {
        case .day: self = .day
        case .dayThenDeck: self = .dayThenDeck
        case .deckThenDay: self = .deckThenDay
        case .intervalsAscending: self = .intervalsAscending
        case .intervalsDescending: self = .intervalsDescending
        case .easeAscending: self = .easeAscending
        case .easeDescending: self = .easeDescending
        case .retrievabilityAscending: self = .retrievabilityAscending
        case .retrievabilityDescending: self = .retrievabilityDescending
        case .random: self = .random
        case .added: self = .added
        case .reverseAdded: self = .reverseAdded
        case .UNRECOGNIZED: self = .day
        }
    }
}

package extension Anki_DeckConfig_DeckConfig.Config.ReviewMix {
    init(_ mirror: ReviewMix) {
        switch mirror {
        case .mixWithReviews: self = .mixWithReviews
        case .afterReviews: self = .afterReviews
        case .beforeReviews: self = .beforeReviews
        }
    }
}

package extension ReviewMix {
    init(_ proto: Anki_DeckConfig_DeckConfig.Config.ReviewMix) {
        switch proto {
        case .mixWithReviews: self = .mixWithReviews
        case .afterReviews: self = .afterReviews
        case .beforeReviews: self = .beforeReviews
        case .UNRECOGNIZED: self = .mixWithReviews
        }
    }
}

package extension Anki_DeckConfig_DeckConfig.Config.LeechAction {
    init(_ mirror: LeechAction) {
        switch mirror {
        case .suspend: self = .suspend
        case .tagOnly: self = .tagOnly
        }
    }
}

package extension LeechAction {
    init(_ proto: Anki_DeckConfig_DeckConfig.Config.LeechAction) {
        switch proto {
        case .suspend: self = .suspend
        case .tagOnly: self = .tagOnly
        case .UNRECOGNIZED: self = .suspend
        }
    }
}

package extension Anki_DeckConfig_DeckConfig.Config.AnswerAction {
    init(_ mirror: AnswerAction) {
        switch mirror {
        case .buryCard: self = .buryCard
        case .answerAgain: self = .answerAgain
        case .answerGood: self = .answerGood
        case .answerHard: self = .answerHard
        case .showReminder: self = .showReminder
        }
    }
}

package extension AnswerAction {
    init(_ proto: Anki_DeckConfig_DeckConfig.Config.AnswerAction) {
        switch proto {
        case .buryCard: self = .buryCard
        case .answerAgain: self = .answerAgain
        case .answerGood: self = .answerGood
        case .answerHard: self = .answerHard
        case .showReminder: self = .showReminder
        case .UNRECOGNIZED: self = .buryCard
        }
    }
}

package extension Anki_DeckConfig_DeckConfig.Config.QuestionAction {
    init(_ mirror: QuestionAction) {
        switch mirror {
        case .showAnswer: self = .showAnswer
        case .showReminder: self = .showReminder
        }
    }
}

package extension QuestionAction {
    init(_ proto: Anki_DeckConfig_DeckConfig.Config.QuestionAction) {
        switch proto {
        case .showAnswer: self = .showAnswer
        case .showReminder: self = .showReminder
        case .UNRECOGNIZED: self = .showAnswer
        }
    }
}

package extension Anki_DeckConfig_UpdateDeckConfigsMode {
    init(_ mirror: UpdateDeckConfigsMode) {
        switch mirror {
        case .normal: self = .normal
        case .applyToChildren: self = .applyToChildren
        case .computeAllParams: self = .computeAllParams
        }
    }
}

package extension UpdateDeckConfigsMode {
    init(_ proto: Anki_DeckConfig_UpdateDeckConfigsMode) {
        switch proto {
        case .normal: self = .normal
        case .applyToChildren: self = .applyToChildren
        case .computeAllParams: self = .computeAllParams
        case .UNRECOGNIZED: self = .normal
        }
    }
}
