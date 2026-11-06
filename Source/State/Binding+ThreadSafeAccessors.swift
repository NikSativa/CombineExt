import SwiftUI

extension Binding {
    init(threadSafeGet get: @escaping () -> Value, threadSafeSet set: @escaping (Value) -> Void) {
        let accessors = ThreadSafeAccessors(get: get, set: set)
        self.init(get: {
            return accessors.get()
        }, set: { newValue in
            accessors.set(newValue)
        })
    }
}

/// `UIState` and `ManagedState` protect the value with their lock, so the accessors are safe to call from any thread.
private struct ThreadSafeAccessors<Value>: @unchecked Sendable {
    let get: () -> Value
    let set: (Value) -> Void
}
