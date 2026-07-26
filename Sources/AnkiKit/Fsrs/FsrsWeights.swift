/// Wrapper for an FSRS parameter vector. Exists as its own type so call
/// sites have something to name beyond `[Float]` — the values are
/// otherwise opaque numerics whose interpretation is the FSRS engine's.
public struct FsrsWeights: Hashable, Sendable, Codable {
    public let values: [Float]

    public init(_ values: [Float] = []) {
        self.values = values
    }

    public var isEmpty: Bool { values.isEmpty }
    public var count: Int { values.count }
}
