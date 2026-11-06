/// The lock type that `UIState` and `ManagedState` use when the initializer gets no lock.
///
/// Set `.absent`, `.synced`, or `.custom(_:)` to change the lock type of all new instances.
/// The change has no effect on existing instances.
///
/// - Note: The default value is `.synced`.
///
/// ### Example
/// ```swift
/// StateDefaultLock = .absent
/// @UIState var counter = 0
/// @ManagedState var model = MyModel()
/// ```
public nonisolated(unsafe) var StateDefaultLock: StateLock = .synced
