import Testing
import AnkiKit
@testable import AnkiProtoBridge
@testable import AnkiBackend
import AnkiProto
private import SwiftProtobuf

@Suite struct GraphsConversionsTests {
    // MARK: - Simple bucket conversions

    @Test func AddedSeries_converts_int32_keys_to_int() {
        var proto = Anki_Stats_GraphsResponse.Added()
        proto.added = [-1: 5, 0: 10]
        let mirror = AddedSeries(proto)
        #expect(mirror.added[-1] == 5)
        #expect(mirror.added[0] == 10)
    }

    @Test func FutureDueSeries_carries_haveBacklog_and_dailyLoad() {
        var proto = Anki_Stats_GraphsResponse.FutureDue()
        proto.futureDue = [1: 20]
        proto.haveBacklog = true
        proto.dailyLoad = 42
        let mirror = FutureDueSeries(proto)
        #expect(mirror.futureDue[1] == 20)
        #expect(mirror.haveBacklog)
        #expect(mirror.dailyLoad == 42)
    }

    @Test func EaseBuckets_carries_average() {
        var proto = Anki_Stats_GraphsResponse.Eases()
        proto.eases = [250: 8]
        proto.average = 2.5
        let mirror = EaseBuckets(proto)
        #expect(mirror.eases[250] == 8)
        #expect(mirror.average == 2.5)
    }

    // MARK: - Today

    @Test func TodayCounts_widens_uint32_to_int() {
        var proto = Anki_Stats_GraphsResponse.Today()
        proto.answerCount = 42
        proto.answerMillis = 12_000
        proto.matureCount = 5
        let mirror = TodayCounts(proto)
        #expect(mirror.answerCount == 42)
        #expect(mirror.answerMillis == 12_000)
        #expect(mirror.matureCount == 5)
    }

    // MARK: - Hours

    @Test func HoursBuckets_decodes_period_arrays() {
        var hour = Anki_Stats_GraphsResponse.Hours.Hour()
        hour.total = 7
        hour.correct = 5
        var proto = Anki_Stats_GraphsResponse.Hours()
        proto.oneMonth = [hour]
        proto.allTime = [hour, hour]
        let mirror = HoursBuckets(proto)
        #expect(mirror.oneMonth.count == 1)
        #expect(mirror.oneMonth[0].total == 7)
        #expect(mirror.oneMonth[0].correct == 5)
        #expect(mirror.allTime.count == 2)
    }

    // MARK: - Reviews

    @Test func ReviewCountsAndTimes_recurses_into_nested_Reviews() {
        var rev = Anki_Stats_GraphsResponse.ReviewCountsAndTimes.Reviews()
        rev.learn = 3
        rev.relearn = 1
        rev.young = 4
        rev.mature = 2
        rev.filtered = 0
        var proto = Anki_Stats_GraphsResponse.ReviewCountsAndTimes()
        proto.count = [-1: rev, 0: rev]
        proto.time = [0: rev]
        let mirror = ReviewCountsAndTimes(proto)
        #expect(mirror.count[-1]?.learn == 3)
        #expect(mirror.count[0]?.young == 4)
        #expect(mirror.time[0]?.mature == 2)
    }

    // MARK: - Buttons

    @Test func ButtonsBuckets_period_buckets_decode_4_button_arrays() {
        var counts = Anki_Stats_GraphsResponse.Buttons.ButtonCounts()
        counts.learning = [1, 2, 3, 4]
        counts.young = [5, 6, 7, 8]
        counts.mature = [9, 10, 11, 12]
        var proto = Anki_Stats_GraphsResponse.Buttons()
        proto.oneMonth = counts
        let mirror = ButtonsBuckets(proto)
        #expect(mirror.oneMonth.learning == [1, 2, 3, 4])
        #expect(mirror.oneMonth.mature == [9, 10, 11, 12])
    }

    // MARK: - CardCounts

    @Test func CardCountsSeries_includes_inactive_variants() {
        var counts = Anki_Stats_GraphsResponse.CardCounts.Counts()
        counts.newCards = 15
        counts.young = 30
        counts.mature = 100
        counts.suspended = 4
        var proto = Anki_Stats_GraphsResponse.CardCounts()
        proto.includingInactive = counts
        let mirror = CardCountsSeries(proto)
        #expect(mirror.includingInactive.newCards == 15)
        #expect(mirror.includingInactive.young == 30)
        #expect(mirror.includingInactive.suspended == 4)
    }

    // MARK: - TrueRetention

    @Test func TrueRetentionStats_has_six_periods() {
        var ret = Anki_Stats_GraphsResponse.TrueRetentionStats.TrueRetention()
        ret.youngPassed = 7
        ret.maturePassed = 3
        var proto = Anki_Stats_GraphsResponse.TrueRetentionStats()
        proto.today = ret
        proto.allTime = ret
        let mirror = TrueRetentionStats(proto)
        #expect(mirror.today.youngPassed == 7)
        #expect(mirror.allTime.maturePassed == 3)
    }

    // MARK: - Top-level snapshot

    @Test func GraphsSnapshot_round_trip_carries_top_level_fields() throws {
        var proto = Anki_Stats_GraphsResponse()
        proto.fsrs = true
        proto.rolloverHour = 4
        proto.today.answerCount = 50
        proto.added.added = [0: 12]

        let mirror = GraphsSnapshot(proto)
        #expect(mirror.fsrs)
        #expect(mirror.rolloverHour == 4)
        #expect(mirror.today.answerCount == 50)
        #expect(mirror.added.added[0] == 12)
    }

    // MARK: - Request factory

    @Test func graphs_dispatches_to_stats_service() {
        let envelope: Request<GraphsSnapshot> = .graphs(search: "deck:*", days: 30)
        #expect(envelope.serviceId == ServiceID.stats)
        #expect(envelope.methodId == StatsMethod.graphs)
    }

    @Test func graphs_encodes_search_and_days() throws {
        let envelope: Request<GraphsSnapshot> = .graphs(search: "deck:Korean", days: 90)
        let req = try Anki_Stats_GraphsRequest(serializedBytes: envelope.body)
        #expect(req.search == "deck:Korean")
        #expect(req.days == 90)
    }

    @Test func graphs_clamps_negative_days_to_zero() throws {
        let envelope: Request<GraphsSnapshot> = .graphs(search: "", days: -7)
        let req = try Anki_Stats_GraphsRequest(serializedBytes: envelope.body)
        #expect(req.days == 0)
    }
}
