package import Foundation

/// Typed RPC envelope. `AnkiProtoBridge` constructs these via factory
/// methods; service code consumes them via `AnkiBackend.invoke(_:)`. The
/// `decode` closure encapsulates the protobuf response type so callers
/// never see `Anki_*` symbols.
///
/// `encode` is evaluated by `invoke` at dispatch time — *not* at
/// factory-call time. This means:
///   - Encoding errors propagate cleanly (no silent `Data()` fallback).
///   - Time-sensitive fields (`Date()` timestamps in answer payloads)
///     reflect when the RPC is sent, not when the `Request` was built.
public struct Request<Response: Sendable>: Sendable {
    package let serviceId: UInt32
    package let methodId: UInt32
    package let encode: @Sendable () throws -> Data
    package let decode: @Sendable (Data) throws -> Response

    package init(
        serviceId: UInt32,
        methodId: UInt32,
        encode: @escaping @Sendable () throws -> Data,
        decode: @escaping @Sendable (Data) throws -> Response
    ) {
        self.serviceId = serviceId
        self.methodId = methodId
        self.encode = encode
        self.decode = decode
    }

    /// Convenience for factories with no request body (proto3 default).
    package static func empty(
        serviceId: UInt32,
        methodId: UInt32,
        decode: @escaping @Sendable (Data) throws -> Response
    ) -> Self {
        Self(
            serviceId: serviceId,
            methodId: methodId,
            encode: { Data() },
            decode: decode
        )
    }

    /// Materializes the request body. Test-only: production code goes
    /// through `AnkiBackend.invoke(_:)`, which runs the encoder lazily.
    /// Surfaces encoding errors instead of swallowing them.
    package var body: Data {
        get throws { try encode() }
    }
}
