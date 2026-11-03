import Foundation

/// The lock type of a `ManagedState` instance.
///
/// The lock protects reads and writes of the managed value.
///
/// - `absent`: No lock. The state is not thread-safe.
/// - `synced`: A recursive lock. This is the default value of `ManagedStateDefaultLock`.
/// - `custom`: A lock that the caller provides.
///
/// ### Example
/// ```swift
/// let model = ManagedState(wrappedValue: state, lock: .custom(NSRecursiveLock()))
/// ```
public enum ManagedStateLock {
    /// No lock.
    ///
    /// Use this lock type only when one thread reads and writes the state.
    case absent

    /// A recursive lock.
    ///
    /// - Important: A single read or a single write is thread-safe. A compound operation, such as `state.count += 1`, is not atomic.
    ///   Use `withLock(_:)` for a read-modify-write operation.
    case synced

    /// A lock that the caller provides.
    ///
    /// - Important: `ManagedState` notifies Combine subscribers and Observation observers while it holds the lock.
    ///   If they read the state during the notification, they take the lock again on the same thread.
    ///   Use a recursive lock, such as `NSRecursiveLock`, in this case. A non-recursive lock, such as `NSLock`, causes a deadlock.
    ///
    /// - Parameter lock: An object that conforms to `NSLocking`, for example `NSRecursiveLock`.
    case custom(NSLocking)
}
