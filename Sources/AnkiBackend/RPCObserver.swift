import Foundation

/// One Rust-backend RPC, observed end-to-end. Emitted by `AnkiBackend`
/// after every `invoke(_:)` call (success or failure) when an observer
/// was passed at init time.
public struct RPCEvent: Sendable {
    /// Numeric service ID dispatched (e.g. 13 = scheduler). Compare
    /// against `ServiceID` constants in AnkiProtoBridge when wiring
    /// observers.
    public let serviceId: UInt32
    /// Numeric method ID within the service.
    public let methodId: UInt32
    /// Wall-clock duration spanning encode + FFI call + decode.
    public let duration: Duration
    /// `nil` on success; the thrown error otherwise. Untyped
    /// because encoding/decoding can surface either `BackendError`
    /// or `SwiftProtobuf`'s error types.
    public let error: (any Error)?

    public init(serviceId: UInt32, methodId: UInt32, duration: Duration, error: (any Error)? = nil) {
        self.serviceId = serviceId
        self.methodId = methodId
        self.duration = duration
        self.error = error
    }

    /// True when the RPC completed without throwing.
    public var succeeded: Bool { error == nil }
}

/// Observer closure invoked once per RPC. Pass at `AnkiBackend.init`.
/// The closure is `@Sendable` and may be called from any thread the
/// backend dispatches on; default impls log or fan out to a queue.
public typealias RPCObserver = @Sendable (RPCEvent) -> Void
