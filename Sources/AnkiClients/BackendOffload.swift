/// Hops a synchronous Engine call off the caller's actor. Client
/// `liveValue` closures wrap their service calls in this so `@MainActor`
/// models never run an RPC (or wait on the backend's global lock) on the
/// main thread. Required because `NonisolatedNonsendingByDefault` makes
/// bare `async` closures run on the caller's actor. Mirrors the async
/// `AnkiBackend.invoke` overload.
package func backendOffload<R: Sendable>(
    _ work: @escaping @Sendable () throws -> R
) async throws -> R {
    try await Task.detached(priority: .userInitiated) { try work() }.value
}
