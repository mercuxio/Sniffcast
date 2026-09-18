import Observation

/// Runs `body` now and again whenever any observable property it read changes.
/// `withObservationTracking` fires once per registration, so each change re-arms it.
/// Tracking is event-driven: nothing runs while observed state is unchanged.
@MainActor
func observe(_ body: @escaping @MainActor () -> Void) {
    withObservationTracking(body) {
        Task { @MainActor in observe(body) }
    }
}
