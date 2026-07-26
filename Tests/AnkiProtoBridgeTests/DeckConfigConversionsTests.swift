import Testing
import AnkiKit
@testable import AnkiProtoBridge
@testable import AnkiBackend
import AnkiProto

@Suite struct DeckConfigConversionsTests {
    // MARK: - Enum exhaustiveness

    @Test func LeechAction_round_trip_covers_all_cases() {
        for mirror in LeechAction.allCases {
            let proto = Anki_DeckConfig_DeckConfig.Config.LeechAction(mirror)
            #expect(LeechAction(proto) == mirror)
        }
    }

    @Test func NewCardInsertOrder_round_trip_covers_all_cases() {
        for mirror in NewCardInsertOrder.allCases {
            #expect(NewCardInsertOrder(.init(mirror)) == mirror)
        }
    }

    @Test func NewCardGatherPriority_round_trip_covers_all_cases() {
        for mirror in NewCardGatherPriority.allCases {
            #expect(NewCardGatherPriority(.init(mirror)) == mirror)
        }
    }

    @Test func NewCardSortOrder_round_trip_covers_all_cases() {
        for mirror in NewCardSortOrder.allCases {
            #expect(NewCardSortOrder(.init(mirror)) == mirror)
        }
    }

    @Test func ReviewCardOrder_round_trip_covers_all_cases() {
        for mirror in ReviewCardOrder.allCases {
            #expect(ReviewCardOrder(.init(mirror)) == mirror)
        }
    }

    @Test func ReviewMix_round_trip_covers_all_cases() {
        for mirror in ReviewMix.allCases {
            #expect(ReviewMix(.init(mirror)) == mirror)
        }
    }

    @Test func AnswerAction_round_trip_covers_all_cases() {
        for mirror in AnswerAction.allCases {
            #expect(AnswerAction(.init(mirror)) == mirror)
        }
    }

    @Test func QuestionAction_round_trip_covers_all_cases() {
        for mirror in QuestionAction.allCases {
            #expect(QuestionAction(.init(mirror)) == mirror)
        }
    }

    @Test func UpdateDeckConfigsMode_round_trip_covers_all_cases() {
        for mirror in UpdateDeckConfigsMode.allCases {
            #expect(UpdateDeckConfigsMode(.init(mirror)) == mirror)
        }
    }

    @Test func UNRECOGNIZED_proto_falls_back_to_default() {
        let unknown: Anki_DeckConfig_DeckConfig.Config.LeechAction = .UNRECOGNIZED(99)
        #expect(LeechAction(unknown) == .suspend)
    }

    // MARK: - DeckConfig.Config round-trip

    @Test func DeckConfig_Config_round_trip_preserves_scalar_fields() {
        var proto = Anki_DeckConfig_DeckConfig.Config()
        proto.newPerDay = 25
        proto.reviewsPerDay = 250
        proto.leechThreshold = 9
        proto.leechAction = .tagOnly
        proto.maximumReviewInterval = 36500
        proto.intervalMultiplier = 1.05
        proto.fsrsParams6 = [0.1, 0.2, 0.3]
        proto.desiredRetention = 0.9
        proto.paramSearch = "deck:Korean"
        proto.buryNew = true

        let mirror = DeckConfig.Config(proto)
        #expect(mirror.newPerDay == 25)
        #expect(mirror.reviewsPerDay == 250)
        #expect(mirror.leechThreshold == 9)
        #expect(mirror.leechAction == .tagOnly)
        #expect(mirror.maximumReviewInterval == 36500)
        #expect(mirror.intervalMultiplier == 1.05)
        #expect(mirror.fsrsParams6 == [0.1, 0.2, 0.3])
        #expect(mirror.desiredRetention == 0.9)
        #expect(mirror.paramSearch == "deck:Korean")
        #expect(mirror.buryNew)

        let reproto = mirror.toProto()
        #expect(reproto.newPerDay == 25)
        #expect(reproto.leechAction == .tagOnly)
        #expect(reproto.fsrsParams6 == [0.1, 0.2, 0.3])
        #expect(reproto.desiredRetention == 0.9)
    }

    // MARK: - DeckConfigsForUpdate.CurrentDeck.Limits — optional handling

    @Test func Limits_unset_optionals_decode_to_nil() {
        let proto = Anki_DeckConfig_DeckConfigsForUpdate.CurrentDeck.Limits()
        let mirror = DeckConfigsForUpdate.CurrentDeck.Limits(proto)
        #expect(mirror.review == nil)
        #expect(mirror.new == nil)
        #expect(mirror.reviewToday == nil)
        #expect(mirror.newToday == nil)
        #expect(mirror.desiredRetention == nil)
        #expect(!mirror.reviewTodayActive)
    }

    @Test func Limits_set_optionals_decode_to_value() {
        var proto = Anki_DeckConfig_DeckConfigsForUpdate.CurrentDeck.Limits()
        proto.review = 100
        proto.desiredRetention = 0.92
        let mirror = DeckConfigsForUpdate.CurrentDeck.Limits(proto)
        #expect(mirror.review == 100)
        #expect(mirror.desiredRetention == 0.92)
    }

    @Test func Limits_round_trip_keeps_optional_distinction() throws {
        var proto = Anki_DeckConfig_DeckConfigsForUpdate.CurrentDeck.Limits()
        proto.new = 7
        let mirror = DeckConfigsForUpdate.CurrentDeck.Limits(proto)
        let reproto = mirror.toProto()
        #expect(reproto.hasNew)
        #expect(reproto.new == 7)
        #expect(!reproto.hasReview)
    }

    // MARK: - DeckConfigsForUpdate

    @Test func DeckConfigsForUpdate_decodes_with_or_without_optional_fields() {
        var proto = Anki_DeckConfig_DeckConfigsForUpdate()
        proto.cardStateCustomizer = "card-state"
        proto.fsrs = true
        // No currentDeck, no defaults set — both should decode to nil.

        let mirror = DeckConfigsForUpdate(proto)
        #expect(mirror.cardStateCustomizer == "card-state")
        #expect(mirror.fsrs)
        #expect(mirror.currentDeck == nil)
        #expect(mirror.defaults == nil)
    }

    // MARK: - UpdateDeckConfigsRequest

    @Test func UpdateDeckConfigsRequest_encodes_mode_and_passes_through_limits() throws {
        let limits = DeckConfigsForUpdate.CurrentDeck.Limits(review: 50)
        let request = UpdateDeckConfigsRequest(
            targetDeckID: DeckID(1),
            configs: [DeckConfig(id: DeckConfigID(7), name: "Test")],
            removedConfigIds: [DeckConfigID(2)],
            mode: .computeAllParams,
            cardStateCustomizer: "custom",
            limits: limits,
            newCardsIgnoreReviewLimit: true,
            fsrs: true,
            applyAllParentLimits: false,
            fsrsHealthCheck: true
        )

        let proto = request.toProto()
        #expect(proto.targetDeckID == 1)
        #expect(proto.configs.count == 1)
        #expect(proto.configs[0].id == 7)
        #expect(proto.removedConfigIds == [2])
        #expect(proto.mode == .computeAllParams)
        #expect(proto.cardStateCustomizer == "custom")
        #expect(proto.hasLimits)
        #expect(proto.limits.review == 50)
        #expect(proto.newCardsIgnoreReviewLimit)
        #expect(proto.fsrs)
        #expect(proto.fsrsHealthCheck)
    }

    // MARK: - Request factories

    @Test func deckConfigsForUpdate_dispatches_correctly() {
        let envelope: Request<DeckConfigsForUpdate> = .deckConfigsForUpdate(deckId: DeckID(42))
        #expect(envelope.serviceId == ServiceID.deckConfig)
        #expect(envelope.methodId == DeckConfigMethod.getDeckConfigsForUpdate)
    }

    @Test func deckConfig_dispatches_correctly() {
        let envelope: Request<DeckConfig> = .deckConfig(for: DeckConfigID(99))
        #expect(envelope.serviceId == ServiceID.deckConfig)
        #expect(envelope.methodId == DeckConfigMethod.getDeckConfig)
    }

    @Test func updateDeckConfigs_dispatches_correctly() {
        let request = UpdateDeckConfigsRequest(targetDeckID: DeckID(1), configs: [])
        let envelope: Request<Void> = .updateDeckConfigs(request)
        #expect(envelope.serviceId == ServiceID.deckConfig)
        #expect(envelope.methodId == DeckConfigMethod.updateDeckConfigs)
    }
}
