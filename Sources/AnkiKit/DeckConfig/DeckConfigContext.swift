/// Mirror for `Anki_DeckConfig_DeckConfigsForUpdate`. Carries the
/// preset list, the current deck's metadata, the defaults, and the
/// per-collection FSRS toggles that DeckConfigView surfaces.
public struct DeckConfigsForUpdate: Sendable, Hashable {
    public var allConfig: [ConfigWithExtra]
    public var currentDeck: CurrentDeck?
    public var defaults: DeckConfig?
    public var schemaModified: Bool
    public var cardStateCustomizer: String
    public var newCardsIgnoreReviewLimit: Bool
    public var fsrs: Bool
    public var fsrsHealthCheck: Bool
    public var fsrsLegacyEvaluate: Bool
    public var applyAllParentLimits: Bool
    public var daysSinceLastFsrsOptimize: Int

    public init(
        allConfig: [ConfigWithExtra] = [],
        currentDeck: CurrentDeck? = nil,
        defaults: DeckConfig? = nil,
        schemaModified: Bool = false,
        cardStateCustomizer: String = "",
        newCardsIgnoreReviewLimit: Bool = false,
        fsrs: Bool = false,
        fsrsHealthCheck: Bool = false,
        fsrsLegacyEvaluate: Bool = false,
        applyAllParentLimits: Bool = false,
        daysSinceLastFsrsOptimize: Int = 0
    ) {
        self.allConfig = allConfig
        self.currentDeck = currentDeck
        self.defaults = defaults
        self.schemaModified = schemaModified
        self.cardStateCustomizer = cardStateCustomizer
        self.newCardsIgnoreReviewLimit = newCardsIgnoreReviewLimit
        self.fsrs = fsrs
        self.fsrsHealthCheck = fsrsHealthCheck
        self.fsrsLegacyEvaluate = fsrsLegacyEvaluate
        self.applyAllParentLimits = applyAllParentLimits
        self.daysSinceLastFsrsOptimize = daysSinceLastFsrsOptimize
    }

    public struct ConfigWithExtra: Sendable, Hashable {
        public var config: DeckConfig
        public var useCount: Int

        public init(config: DeckConfig, useCount: Int = 0) {
            self.config = config
            self.useCount = useCount
        }
    }

    public struct CurrentDeck: Sendable, Hashable {
        public var name: String
        public var configID: DeckConfigID
        public var parentConfigIds: [DeckConfigID]
        public var limits: Limits?

        public init(
            name: String = "",
            configID: DeckConfigID = DeckConfigID(0),
            parentConfigIds: [DeckConfigID] = [],
            limits: Limits? = nil
        ) {
            self.name = name
            self.configID = configID
            self.parentConfigIds = parentConfigIds
            self.limits = limits
        }

        public struct Limits: Sendable, Hashable {
            /// Per-day overrides. `nil` means "use the preset value."
            public var review: Int?
            public var new: Int?
            public var reviewToday: Int?
            public var newToday: Int?
            public var reviewTodayActive: Bool
            public var newTodayActive: Bool
            /// Deck-specific desired retention override; `nil` means
            /// "inherit from the preset."
            public var desiredRetention: Float?

            public init(
                review: Int? = nil,
                new: Int? = nil,
                reviewToday: Int? = nil,
                newToday: Int? = nil,
                reviewTodayActive: Bool = false,
                newTodayActive: Bool = false,
                desiredRetention: Float? = nil
            ) {
                self.review = review
                self.new = new
                self.reviewToday = reviewToday
                self.newToday = newToday
                self.reviewTodayActive = reviewTodayActive
                self.newTodayActive = newTodayActive
                self.desiredRetention = desiredRetention
            }
        }
    }
}

/// Mirror for `Anki_DeckConfig_UpdateDeckConfigsRequest`. Surfaces only
/// the fields service code currently populates — the full proto carries
/// fsrs-reschedule-related toggles that are deferred until a consumer
/// needs them.
public struct UpdateDeckConfigsRequest: Sendable, Hashable {
    public var targetDeckID: DeckID
    public var configs: [DeckConfig]
    public var removedConfigIds: [DeckConfigID]
    public var mode: UpdateDeckConfigsMode
    public var cardStateCustomizer: String
    public var limits: DeckConfigsForUpdate.CurrentDeck.Limits?
    public var newCardsIgnoreReviewLimit: Bool
    public var fsrs: Bool
    public var applyAllParentLimits: Bool
    public var fsrsReschedule: Bool
    public var fsrsHealthCheck: Bool

    public init(
        targetDeckID: DeckID,
        configs: [DeckConfig],
        removedConfigIds: [DeckConfigID] = [],
        mode: UpdateDeckConfigsMode = .normal,
        cardStateCustomizer: String = "",
        limits: DeckConfigsForUpdate.CurrentDeck.Limits? = nil,
        newCardsIgnoreReviewLimit: Bool = false,
        fsrs: Bool = false,
        applyAllParentLimits: Bool = false,
        fsrsReschedule: Bool = false,
        fsrsHealthCheck: Bool = false
    ) {
        self.targetDeckID = targetDeckID
        self.configs = configs
        self.removedConfigIds = removedConfigIds
        self.mode = mode
        self.cardStateCustomizer = cardStateCustomizer
        self.limits = limits
        self.newCardsIgnoreReviewLimit = newCardsIgnoreReviewLimit
        self.fsrs = fsrs
        self.applyAllParentLimits = applyAllParentLimits
        self.fsrsReschedule = fsrsReschedule
        self.fsrsHealthCheck = fsrsHealthCheck
    }
}
