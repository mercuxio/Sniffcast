import Observation

/// Calls `apply` with `read()` now, and again whenever an observable property read *inside
/// `read`* changes. Only `read` is tracked: side effects in `apply` may touch any state
/// without subscribing to it. `withObservationTracking` fires once per registration, so each
/// change re-arms it. Nothing runs while observed state is unchanged.
@MainActor
func observe<Value>(_ read: @escaping @MainActor () -> Value, apply: @escaping @MainActor (Value) -> Void) {
    let value = withObservationTracking(read) {
        Task { @MainActor in observe(read, apply: apply) }
    }
    apply(value)
}
