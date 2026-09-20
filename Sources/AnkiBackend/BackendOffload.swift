//
//  BackendOffload.swift
//  AnkiBackend
//
//  Created by Vladimir Gusev on 20.08.2026.
//

/// Hops a synchronous Engine call off the caller's actor.
///
/// `AnkiClients` live values — and the handful of feature models that call an
/// `AnkiServices` facade directly — wrap their bodies in this so a
/// `@MainActor` model never runs an RPC, or waits on the backend's global
/// lock, on the main thread. Required because `NonisolatedNonsendingByDefault`
/// makes a bare `async` function run on the *caller's* actor, so declaring a
/// facade `async` is not on its own enough to get off the main thread.
///
/// `@concurrent` rather than `Task.detached`: the work runs in the *caller's*
/// task on the global executor, so cancellation propagates into it, task-local
/// values (the `withDependencies` scope among them) survive the hop, and the
/// caller's priority is inherited instead of pinned to `.userInitiated`.
///
/// One hop per facade call: wrap the whole closure body rather than each
/// individual `invoke`, so a body doing several RPCs pays one context
/// switch instead of several.
@concurrent
public func backendOffload<R: Sendable>(
    _ work: @Sendable () throws -> R
) async throws -> R {
    try work()
}
