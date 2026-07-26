package import AnkiKit
package import AnkiProto

// MARK: - DeckConfig.Config <-> Anki_DeckConfig_DeckConfig.Config

package extension DeckConfig.Config {
    init(_ proto: Anki_DeckConfig_DeckConfig.Config) {
        self.init(
            learnSteps: proto.learnSteps,
            relearnSteps: proto.relearnSteps,
            fsrsParams4: proto.fsrsParams4,
            fsrsParams5: proto.fsrsParams5,
            fsrsParams6: proto.fsrsParams6,
            newPerDay: Int(proto.newPerDay),
            reviewsPerDay: Int(proto.reviewsPerDay),
            newPerDayMinimum: Int(proto.newPerDayMinimum),
            initialEase: proto.initialEase,
            easyMultiplier: proto.easyMultiplier,
            hardMultiplier: proto.hardMultiplier,
            lapseMultiplier: proto.lapseMultiplier,
            intervalMultiplier: proto.intervalMultiplier,
            maximumReviewInterval: Int(proto.maximumReviewInterval),
            minimumLapseInterval: Int(proto.minimumLapseInterval),
            graduatingIntervalGood: Int(proto.graduatingIntervalGood),
            graduatingIntervalEasy: Int(proto.graduatingIntervalEasy),
            newCardInsertOrder: NewCardInsertOrder(proto.newCardInsertOrder),
            newCardGatherPriority: NewCardGatherPriority(proto.newCardGatherPriority),
            newCardSortOrder: NewCardSortOrder(proto.newCardSortOrder),
            newMix: ReviewMix(proto.newMix),
            reviewOrder: ReviewCardOrder(proto.reviewOrder),
            interdayLearningMix: ReviewMix(proto.interdayLearningMix),
            leechAction: LeechAction(proto.leechAction),
            leechThreshold: Int(proto.leechThreshold),
            disableAutoplay: proto.disableAutoplay,
            capAnswerTimeToSecs: Int(proto.capAnswerTimeToSecs),
            showTimer: proto.showTimer,
            stopTimerOnAnswer: proto.stopTimerOnAnswer,
            secondsToShowQuestion: proto.secondsToShowQuestion,
            secondsToShowAnswer: proto.secondsToShowAnswer,
            questionAction: QuestionAction(proto.questionAction),
            answerAction: AnswerAction(proto.answerAction),
            waitForAudio: proto.waitForAudio,
            skipQuestionWhenReplayingAnswer: proto.skipQuestionWhenReplayingAnswer,
            buryNew: proto.buryNew,
            buryReviews: proto.buryReviews,
            buryInterdayLearning: proto.buryInterdayLearning,
            desiredRetention: proto.desiredRetention,
            ignoreRevlogsBeforeDate: proto.ignoreRevlogsBeforeDate,
            easyDaysPercentages: proto.easyDaysPercentages,
            historicalRetention: proto.historicalRetention,
            paramSearch: proto.paramSearch,
            other: proto.other
        )
    }

    func toProto() -> Anki_DeckConfig_DeckConfig.Config {
        var proto = Anki_DeckConfig_DeckConfig.Config()
        proto.learnSteps = learnSteps
        proto.relearnSteps = relearnSteps
        proto.fsrsParams4 = fsrsParams4
        proto.fsrsParams5 = fsrsParams5
        proto.fsrsParams6 = fsrsParams6
        proto.newPerDay = UInt32(max(0, newPerDay))
        proto.reviewsPerDay = UInt32(max(0, reviewsPerDay))
        proto.newPerDayMinimum = UInt32(max(0, newPerDayMinimum))
        proto.initialEase = initialEase
        proto.easyMultiplier = easyMultiplier
        proto.hardMultiplier = hardMultiplier
        proto.lapseMultiplier = lapseMultiplier
        proto.intervalMultiplier = intervalMultiplier
        proto.maximumReviewInterval = UInt32(max(0, maximumReviewInterval))
        proto.minimumLapseInterval = UInt32(max(0, minimumLapseInterval))
        proto.graduatingIntervalGood = UInt32(max(0, graduatingIntervalGood))
        proto.graduatingIntervalEasy = UInt32(max(0, graduatingIntervalEasy))
        proto.newCardInsertOrder = .init(newCardInsertOrder)
        proto.newCardGatherPriority = .init(newCardGatherPriority)
        proto.newCardSortOrder = .init(newCardSortOrder)
        proto.newMix = .init(newMix)
        proto.reviewOrder = .init(reviewOrder)
        proto.interdayLearningMix = .init(interdayLearningMix)
        proto.leechAction = .init(leechAction)
        proto.leechThreshold = UInt32(max(0, leechThreshold))
        proto.disableAutoplay = disableAutoplay
        proto.capAnswerTimeToSecs = UInt32(max(0, capAnswerTimeToSecs))
        proto.showTimer = showTimer
        proto.stopTimerOnAnswer = stopTimerOnAnswer
        proto.secondsToShowQuestion = secondsToShowQuestion
        proto.secondsToShowAnswer = secondsToShowAnswer
        proto.questionAction = .init(questionAction)
        proto.answerAction = .init(answerAction)
        proto.waitForAudio = waitForAudio
        proto.skipQuestionWhenReplayingAnswer = skipQuestionWhenReplayingAnswer
        proto.buryNew = buryNew
        proto.buryReviews = buryReviews
        proto.buryInterdayLearning = buryInterdayLearning
        proto.desiredRetention = desiredRetention
        proto.ignoreRevlogsBeforeDate = ignoreRevlogsBeforeDate
        proto.easyDaysPercentages = easyDaysPercentages
        proto.historicalRetention = historicalRetention
        proto.paramSearch = paramSearch
        proto.other = other
        return proto
    }
}

// MARK: - DeckConfig <-> Anki_DeckConfig_DeckConfig

package extension DeckConfig {
    init(_ proto: Anki_DeckConfig_DeckConfig) {
        self.init(
            id: DeckConfigID(proto.id),
            name: proto.name,
            mtimeSecs: proto.mtimeSecs,
            usn: proto.usn,
            config: Config(proto.config)
        )
    }
}

extension DeckConfig: BridgeDecodable {
    package typealias Proto = Anki_DeckConfig_DeckConfig
}

package extension DeckConfig {
    func toProto() -> Anki_DeckConfig_DeckConfig {
        var proto = Anki_DeckConfig_DeckConfig()
        proto.id = id.rawValue
        proto.name = name
        proto.mtimeSecs = mtimeSecs
        proto.usn = usn
        proto.config = config.toProto()
        return proto
    }
}

// MARK: - DeckConfigsForUpdate <-> Anki_DeckConfig_DeckConfigsForUpdate

package extension DeckConfigsForUpdate.ConfigWithExtra {
    init(_ proto: Anki_DeckConfig_DeckConfigsForUpdate.ConfigWithExtra) {
        self.init(
            config: DeckConfig(proto.config),
            useCount: Int(proto.useCount)
        )
    }

    func toProto() -> Anki_DeckConfig_DeckConfigsForUpdate.ConfigWithExtra {
        var proto = Anki_DeckConfig_DeckConfigsForUpdate.ConfigWithExtra()
        proto.config = config.toProto()
        proto.useCount = UInt32(max(0, useCount))
        return proto
    }
}

package extension DeckConfigsForUpdate.CurrentDeck.Limits {
    init(_ proto: Anki_DeckConfig_DeckConfigsForUpdate.CurrentDeck.Limits) {
        self.init(
            review: proto.hasReview ? Int(proto.review) : nil,
            new: proto.hasNew ? Int(proto.new) : nil,
            reviewToday: proto.hasReviewToday ? Int(proto.reviewToday) : nil,
            newToday: proto.hasNewToday ? Int(proto.newToday) : nil,
            reviewTodayActive: proto.reviewTodayActive,
            newTodayActive: proto.newTodayActive,
            desiredRetention: proto.hasDesiredRetention ? proto.desiredRetention : nil
        )
    }

    func toProto() -> Anki_DeckConfig_DeckConfigsForUpdate.CurrentDeck.Limits {
        var proto = Anki_DeckConfig_DeckConfigsForUpdate.CurrentDeck.Limits()
        if let review { proto.review = UInt32(max(0, review)) }
        if let new { proto.new = UInt32(max(0, new)) }
        if let reviewToday { proto.reviewToday = UInt32(max(0, reviewToday)) }
        if let newToday { proto.newToday = UInt32(max(0, newToday)) }
        proto.reviewTodayActive = reviewTodayActive
        proto.newTodayActive = newTodayActive
        if let desiredRetention { proto.desiredRetention = desiredRetention }
        return proto
    }
}

package extension DeckConfigsForUpdate.CurrentDeck {
    init(_ proto: Anki_DeckConfig_DeckConfigsForUpdate.CurrentDeck) {
        self.init(
            name: proto.name,
            configID: DeckConfigID(proto.configID),
            parentConfigIds: proto.parentConfigIds.map { DeckConfigID($0) },
            limits: proto.hasLimits ? Limits(proto.limits) : nil
        )
    }

    func toProto() -> Anki_DeckConfig_DeckConfigsForUpdate.CurrentDeck {
        var proto = Anki_DeckConfig_DeckConfigsForUpdate.CurrentDeck()
        proto.name = name
        proto.configID = configID.rawValue
        proto.parentConfigIds = parentConfigIds.map(\.rawValue)
        if let limits {
            proto.limits = limits.toProto()
        }
        return proto
    }
}

package extension DeckConfigsForUpdate {
    init(_ proto: Anki_DeckConfig_DeckConfigsForUpdate) {
        self.init(
            allConfig: proto.allConfig.map(ConfigWithExtra.init),
            currentDeck: proto.hasCurrentDeck ? CurrentDeck(proto.currentDeck) : nil,
            defaults: proto.hasDefaults ? DeckConfig(proto.defaults) : nil,
            schemaModified: proto.schemaModified,
            cardStateCustomizer: proto.cardStateCustomizer,
            newCardsIgnoreReviewLimit: proto.newCardsIgnoreReviewLimit,
            fsrs: proto.fsrs,
            fsrsHealthCheck: proto.fsrsHealthCheck,
            fsrsLegacyEvaluate: proto.fsrsLegacyEvaluate,
            applyAllParentLimits: proto.applyAllParentLimits,
            daysSinceLastFsrsOptimize: Int(proto.daysSinceLastFsrsOptimize)
        )
    }
}

extension DeckConfigsForUpdate: BridgeDecodable {
    package typealias Proto = Anki_DeckConfig_DeckConfigsForUpdate
}

// MARK: - UpdateDeckConfigsRequest -> proto

package extension UpdateDeckConfigsRequest {
    func toProto() -> Anki_DeckConfig_UpdateDeckConfigsRequest {
        var proto = Anki_DeckConfig_UpdateDeckConfigsRequest()
        proto.targetDeckID = targetDeckID.rawValue
        proto.configs = configs.map { $0.toProto() }
        proto.removedConfigIds = removedConfigIds.map(\.rawValue)
        proto.mode = .init(mode)
        proto.cardStateCustomizer = cardStateCustomizer
        if let limits { proto.limits = limits.toProto() }
        proto.newCardsIgnoreReviewLimit = newCardsIgnoreReviewLimit
        proto.fsrs = fsrs
        proto.applyAllParentLimits = applyAllParentLimits
        proto.fsrsReschedule = fsrsReschedule
        proto.fsrsHealthCheck = fsrsHealthCheck
        return proto
    }
}
