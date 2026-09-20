//
//  StatsDashboardContentStateTests.swift
//  StatsFeatureTests
//
//  Created by Vladimir Gusev on 10.08.2026.
//

import AnkiClients
import AnkiKit
import Dependencies
import Testing
@testable import StatsFeature

/// These rules used to be asserted against a `State(isLoading:errorMessage:
/// graphs:)` projecting init, which `3b3948f` deleted when the model started
/// storing the enum directly. The precedence itself moved into `loadStats`,
/// so the tests follow it there.
@MainActor
@Suite("StatsDashboardModel.loadStats state precedence")
struct StatsDashboardContentStateTests {

    private struct Boom: Error {}

    /// Records `model.state` as observed from inside the in-flight fetch —
    /// the only way to see whether a refresh flashed the spinner.
    @MainActor
    private final class Probe {
        var stateDuringFetch: StatsDashboardContent.State?
    }

    private func makeModel(
        _ probe: Probe,
        result: @escaping @Sendable () throws -> GraphsSnapshot
    ) -> StatsDashboardModel {
        var model: StatsDashboardModel?
        let built = withDependencies {
            $0.statsClient = StatsClient { _, _ in
                await MainActor.run { probe.stateDuringFetch = model?.state }
                return try result()
            }
        } operation: {
            StatsDashboardModel()
        }
        model = built
        return built
    }

    @Test("a first load shows the spinner, then the graphs")
    func firstLoadShowsSpinner() async {
        let probe = Probe()
        let model = makeModel(probe) { GraphsSnapshot() }

        await model.loadStats(search: "", days: 30)

        #expect(probe.stateDuringFetch?.isLoading == true)
        #expect(model.state.isLoaded)
    }

    @Test("a refresh keeps the previous graphs on screen instead of flashing a spinner")
    func refreshKeepsGraphs() async {
        let probe = Probe()
        let model = makeModel(probe) { GraphsSnapshot() }
        model.state = .loaded(GraphsSnapshot())

        await model.loadStats(search: "", days: 30)

        #expect(probe.stateDuringFetch?.isLoading == false)
        #expect(model.state.isLoaded)
    }

    @Test("an error wins over stale graphs")
    func errorBeatsStaleGraphs() async {
        let probe = Probe()
        let model = makeModel(probe) { throw Boom() }
        model.state = .loaded(GraphsSnapshot())

        await model.loadStats(search: "", days: 30)

        #expect(model.state.isFailed)
    }

    @Test("an error on a first load is still an error, never a blank screen")
    func errorOnFirstLoad() async {
        let probe = Probe()
        let model = makeModel(probe) { throw Boom() }

        await model.loadStats(search: "", days: 30)

        #expect(model.state.isFailed)
    }
}

private extension StatsDashboardContent.State {
    var isLoading: Bool { if case .loading = self { true } else { false } }
    var isLoaded: Bool { if case .loaded = self { true } else { false } }
    var isFailed: Bool { if case .failed = self { true } else { false } }
}
