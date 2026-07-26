public import Foundation

/// Inputs for `Request.computeFsrsParams`. Mirrors the wire-level
/// `Anki_Scheduler_ComputeFsrsParamsRequest` but uses `Date` for the
/// review-cutoff field and `Int` for relearning-step counts so the type
/// is comfortable for SwiftUI consumers.
public struct FsrsOptimizeRequest: Sendable, Hashable {
    /// Search string used to gather the training set.
    public let search: String
    /// Existing weights — the optimizer uses them as a starting point.
    public let currentWeights: FsrsWeights
    /// Ignore review-log entries earlier than this instant. `nil` means
    /// the entire review history is fair game.
    public let ignoreRevlogsBefore: Date?
    /// Number of relearning steps that the deck performs per day.
    public let relearningStepsPerDay: Int
    /// Whether the optimizer should also report a health-check verdict.
    public let runHealthCheck: Bool

    public init(
        search: String,
        currentWeights: FsrsWeights,
        ignoreRevlogsBefore: Date? = nil,
        relearningStepsPerDay: Int,
        runHealthCheck: Bool
    ) {
        self.search = search
        self.currentWeights = currentWeights
        self.ignoreRevlogsBefore = ignoreRevlogsBefore
        self.relearningStepsPerDay = relearningStepsPerDay
        self.runHealthCheck = runHealthCheck
    }
}

/// Output of `Request.computeFsrsParams`.
public struct FsrsOptimizeResult: Sendable, Hashable {
    /// Health-check verdict. Distinct from "didn't run" — the wire
    /// type uses `hasHealthCheckPassed` to encode that.
    public enum HealthCheck: Sendable, Hashable {
        case passed
        case failed
    }

    /// Optimized weights. Empty when the backend couldn't produce a
    /// result (typically: insufficient review history).
    public let weights: FsrsWeights
    /// Number of training items the optimizer actually used.
    public let trainingItemCount: Int
    /// Health-check verdict if the request asked for one. `nil`
    /// when health-check was disabled.
    public let healthCheck: HealthCheck?

    public init(
        weights: FsrsWeights,
        trainingItemCount: Int,
        healthCheck: HealthCheck?
    ) {
        self.weights = weights
        self.trainingItemCount = trainingItemCount
        self.healthCheck = healthCheck
    }
}
