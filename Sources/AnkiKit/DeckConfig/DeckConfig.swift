public import Foundation

/// Mirror for `Anki_DeckConfig_DeckConfig`. The wire wrapper carries
/// identity + bookkeeping fields plus the inner `Config` payload.
public struct DeckConfig: Sendable, Hashable, Identifiable {
    public var id: DeckConfigID
    public var name: String
    public var mtimeSecs: Int64
    public var usn: Int32
    public var config: Config

    public init(
        id: DeckConfigID = DeckConfigID(0),
        name: String = "",
        mtimeSecs: Int64 = 0,
        usn: Int32 = 0,
        config: Config = Config()
    ) {
        self.id = id
        self.name = name
        self.mtimeSecs = mtimeSecs
        self.usn = usn
        self.config = config
    }

    /// Mirror for `Anki_DeckConfig_DeckConfig.Config` — the per-deck
    /// study settings payload.
    public struct Config: Sendable, Hashable {
        // MARK: Steps + FSRS params
        public var learnSteps: [Float]
        public var relearnSteps: [Float]
        public var fsrsParams4: [Float]
        public var fsrsParams5: [Float]
        public var fsrsParams6: [Float]

        // MARK: Daily limits
        public var newPerDay: Int
        public var reviewsPerDay: Int
        /// Currently unused upstream; preserved for round-trip safety.
        public var newPerDayMinimum: Int

        // MARK: Multipliers + intervals
        public var initialEase: Float
        public var easyMultiplier: Float
        public var hardMultiplier: Float
        public var lapseMultiplier: Float
        public var intervalMultiplier: Float
        public var maximumReviewInterval: Int
        public var minimumLapseInterval: Int
        public var graduatingIntervalGood: Int
        public var graduatingIntervalEasy: Int

        // MARK: New / review ordering
        public var newCardInsertOrder: NewCardInsertOrder
        public var newCardGatherPriority: NewCardGatherPriority
        public var newCardSortOrder: NewCardSortOrder
        public var newMix: ReviewMix
        public var reviewOrder: ReviewCardOrder
        public var interdayLearningMix: ReviewMix

        // MARK: Leeches
        public var leechAction: LeechAction
        public var leechThreshold: Int

        // MARK: Audio + timer
        public var disableAutoplay: Bool
        public var capAnswerTimeToSecs: Int
        public var showTimer: Bool
        public var stopTimerOnAnswer: Bool
        public var secondsToShowQuestion: Float
        public var secondsToShowAnswer: Float
        public var questionAction: QuestionAction
        public var answerAction: AnswerAction
        public var waitForAudio: Bool
        public var skipQuestionWhenReplayingAnswer: Bool

        // MARK: Burying
        public var buryNew: Bool
        public var buryReviews: Bool
        public var buryInterdayLearning: Bool

        // MARK: FSRS
        public var desiredRetention: Float
        public var ignoreRevlogsBeforeDate: String
        public var easyDaysPercentages: [Float]
        public var historicalRetention: Float
        public var paramSearch: String

        /// Opaque add-on/JSON blob the backend round-trips. Passed
        /// through unchanged.
        public var other: Data

        public init(
            learnSteps: [Float] = [],
            relearnSteps: [Float] = [],
            fsrsParams4: [Float] = [],
            fsrsParams5: [Float] = [],
            fsrsParams6: [Float] = [],
            newPerDay: Int = 0,
            reviewsPerDay: Int = 0,
            newPerDayMinimum: Int = 0,
            initialEase: Float = 0,
            easyMultiplier: Float = 0,
            hardMultiplier: Float = 0,
            lapseMultiplier: Float = 0,
            intervalMultiplier: Float = 0,
            maximumReviewInterval: Int = 0,
            minimumLapseInterval: Int = 0,
            graduatingIntervalGood: Int = 0,
            graduatingIntervalEasy: Int = 0,
            newCardInsertOrder: NewCardInsertOrder = .due,
            newCardGatherPriority: NewCardGatherPriority = .deck,
            newCardSortOrder: NewCardSortOrder = .template,
            newMix: ReviewMix = .mixWithReviews,
            reviewOrder: ReviewCardOrder = .day,
            interdayLearningMix: ReviewMix = .mixWithReviews,
            leechAction: LeechAction = .suspend,
            leechThreshold: Int = 0,
            disableAutoplay: Bool = false,
            capAnswerTimeToSecs: Int = 0,
            showTimer: Bool = false,
            stopTimerOnAnswer: Bool = false,
            secondsToShowQuestion: Float = 0,
            secondsToShowAnswer: Float = 0,
            questionAction: QuestionAction = .showAnswer,
            answerAction: AnswerAction = .buryCard,
            waitForAudio: Bool = false,
            skipQuestionWhenReplayingAnswer: Bool = false,
            buryNew: Bool = false,
            buryReviews: Bool = false,
            buryInterdayLearning: Bool = false,
            desiredRetention: Float = 0,
            ignoreRevlogsBeforeDate: String = "",
            easyDaysPercentages: [Float] = [],
            historicalRetention: Float = 0,
            paramSearch: String = "",
            other: Data = Data()
        ) {
            self.learnSteps = learnSteps
            self.relearnSteps = relearnSteps
            self.fsrsParams4 = fsrsParams4
            self.fsrsParams5 = fsrsParams5
            self.fsrsParams6 = fsrsParams6
            self.newPerDay = newPerDay
            self.reviewsPerDay = reviewsPerDay
            self.newPerDayMinimum = newPerDayMinimum
            self.initialEase = initialEase
            self.easyMultiplier = easyMultiplier
            self.hardMultiplier = hardMultiplier
            self.lapseMultiplier = lapseMultiplier
            self.intervalMultiplier = intervalMultiplier
            self.maximumReviewInterval = maximumReviewInterval
            self.minimumLapseInterval = minimumLapseInterval
            self.graduatingIntervalGood = graduatingIntervalGood
            self.graduatingIntervalEasy = graduatingIntervalEasy
            self.newCardInsertOrder = newCardInsertOrder
            self.newCardGatherPriority = newCardGatherPriority
            self.newCardSortOrder = newCardSortOrder
            self.newMix = newMix
            self.reviewOrder = reviewOrder
            self.interdayLearningMix = interdayLearningMix
            self.leechAction = leechAction
            self.leechThreshold = leechThreshold
            self.disableAutoplay = disableAutoplay
            self.capAnswerTimeToSecs = capAnswerTimeToSecs
            self.showTimer = showTimer
            self.stopTimerOnAnswer = stopTimerOnAnswer
            self.secondsToShowQuestion = secondsToShowQuestion
            self.secondsToShowAnswer = secondsToShowAnswer
            self.questionAction = questionAction
            self.answerAction = answerAction
            self.waitForAudio = waitForAudio
            self.skipQuestionWhenReplayingAnswer = skipQuestionWhenReplayingAnswer
            self.buryNew = buryNew
            self.buryReviews = buryReviews
            self.buryInterdayLearning = buryInterdayLearning
            self.desiredRetention = desiredRetention
            self.ignoreRevlogsBeforeDate = ignoreRevlogsBeforeDate
            self.easyDaysPercentages = easyDaysPercentages
            self.historicalRetention = historicalRetention
            self.paramSearch = paramSearch
            self.other = other
        }
    }
}
