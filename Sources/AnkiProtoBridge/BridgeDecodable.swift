package import AnkiBackend
package import Foundation
package import SwiftProtobuf

/// Adopted by AnkiKit mirror types that have a direct proto-init
/// (`init(_ proto: Proto)`). Lets `Request` factories skip the
/// boilerplate decode closure.
package protocol BridgeDecodable: Sendable {
    associatedtype Proto: SwiftProtobuf.Message
    init(_ proto: Proto)
}

extension Request where Response: BridgeDecodable {
    /// Builds a request whose decode step is "deserialize the proto
    /// type associated with `Response`, then call `Response.init(_:)`."
    /// Eliminates the repetitive 2-line decode closure across factories
    /// where the mirror already has a proto-init.
    package static func decoded(
        serviceId: UInt32,
        methodId: UInt32,
        encode: @escaping @Sendable () throws -> Data
    ) -> Self {
        Self(
            serviceId: serviceId,
            methodId: methodId,
            encode: encode,
            decode: { bytes in
                Response(try Response.Proto(serializedBytes: bytes))
            }
        )
    }

    /// No-body variant for RPCs the backend infers from collection state.
    package static func decoded(
        serviceId: UInt32,
        methodId: UInt32
    ) -> Self {
        .empty(
            serviceId: serviceId,
            methodId: methodId,
            decode: { bytes in
                Response(try Response.Proto(serializedBytes: bytes))
            }
        )
    }
}
