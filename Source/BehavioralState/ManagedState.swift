import Combine
import Foundation

#if swift(>=6.0)
/// A global flag that enables or disables cyclic dependency assertions in state rules.
///
/// When set to `true`, an assertion is triggered if the number of rule application loops
/// exceeds `ManagedStateCyclicDependencyMaxDepth`. This helps detect unintentional infinite update cycles,
/// such as those caused by improperly configured state feedback loops.
///
/// - Note: Defaults to `true`.
///
/// ### Example
/// ```swift
/// ManagedStateCyclicDependencyWarning = false // Disable warning in tests
/// ```
public nonisolated(unsafe) var ManagedStateCyclicDependencyWarning: Bool = true
/// The maximum number of rule reapplication cycles allowed before assuming a cyclic dependency.
///
/// If this threshold is exceeded while `ManagedStateCyclicDependencyWarning` is enabled,
/// an assertion failure is triggered to prevent infinite loops.
///
/// - Note: Defaults to `100`.
///
/// ### Example
/// ```swift
/// ManagedStateCyclicDependencyMaxDepth = 50 // Tighter threshold for specific workflows
/// ```
public nonisolated(unsafe) var ManagedStateCyclicDependencyMaxDepth: Int = 100
/// The default locking strategy used by `ManagedState` instances.
///
/// When initializing `ManagedState` without providing an explicit lock, this value determines
/// the locking behavior. You can assign `.absent`, `.synced`, or `.custom(...)` to configure the behavior globally.
///
/// - Note: Defaults to `.synced`, which uses a recursive lock for thread safety.
///
/// ### Example
/// ```swift
/// ManagedStateDefaultLock = .absent
/// @ManagedState var model = MyModel() // will use no locking
/// ```
public nonisolated(unsafe) var ManagedStateDefaultLock: ManagedStateLock = .synced
#else
/// A global flag that enables or disables cyclic dependency assertions in state rules.
///
/// When set to `true`, an assertion is triggered if the number of rule application loops
/// exceeds `ManagedStateCyclicDependencyMaxDepth`. This helps detect unintentional infinite update cycles,
/// such as those caused by improperly configured state feedback loops.
///
/// - Note: Defaults to `true`.
///
/// ### Example
/// ```swift
/// ManagedStateCyclicDependencyWarning = false // Disable warning in tests
/// ```
public var ManagedStateCyclicDependencyWarning: Bool = true
/// The maximum number of rule reapplication cycles allowed before assuming a cyclic dependency.
///
/// If this threshold is exceeded while `ManagedStateCyclicDependencyWarning` is enabled,
/// an assertion failure is triggered to prevent infinite loops.
///
/// - Note: Defaults to `100`.
///
/// ### Example
/// ```swift
/// ManagedStateCyclicDependencyMaxDepth = 50 // Tighter threshold for specific workflows
/// ```
public var ManagedStateCyclicDependencyMaxDepth: Int = 100
/// The default locking strategy used by `ManagedState` instances.
///
/// When initializing `ManagedState` without providing an explicit lock, this value determines
/// the locking behavior. You can assign `.absent`, `.synced`, or `.custom(...)` to configure the behavior globally.
///
/// - Note: Defaults to `.synced`, which uses a recursive lock for thread safety.
///
/// ### Example
/// ```swift
/// ManagedStateDefaultLock = .absent
/// @ManagedState var model = MyModel() // will use no locking
/// ```
public var ManagedStateDefaultLock: ManagedStateLock = .synced
#endif

/// Defines the locking mechanism used within a `ManagedState` instance.
///
/// Use this enum to configure how thread safety is enforced when reading and writing state.
///
/// - `absent`: No locking is performed. Not thread-safe.
/// - `synced`: Uses an internal recursive lock for thread safety. Default.
/// - `custom`: Provides a custom lock implementation.
///
/// ### Example
/// ```swift
/// let model = ManagedState(wrappedValue: state, lock: .custom(NSRecursiveLock()))
/// ```
public enum ManagedStateLock {
    /// No synchronization. Use only when thread-safety is not a concern.
    case absent

    /// Uses a recursive lock to ensure thread-safety during state access and updates.
    ///
    /// ⚠️ **Important**: While individual property access is thread-safe, compound operations
    /// like `state.count += 1` are NOT atomic and may cause race conditions in concurrent code.
    /// Use direct assignment `state.count = newValue` for thread-safe updates.
    case synced

    /// Provides a custom locking mechanism conforming to `NSLocking`.
    ///
    /// - Parameter lock: An object conforming to `NSLocking`, such as `NSRecursiveLock` or `NSLock`.
    case custom(NSLocking)
}

/// A property wrapper that manages reactive state conforming to `BehavioralStateContract`.
///
/// `ManagedState` offers automatic rule binding, dynamic UI syncing, and observable state changes using Combine.
/// Suitable for ViewModels and dynamic UI frameworks like SwiftUI or UIKit.
///
/// - Note: This type supports `@dynamicMemberLookup` to simplify access to underlying properties.
///
/// ⚠️ **Thread Safety**: While individual property access is thread-safe, compound operations
/// like `state.count += 1` are NOT atomic and may cause race conditions in concurrent code.
/// Use direct assignment for thread-safe updates: `state.count = newValue`.
///
/// ### Example
/// ```swift
/// struct MyState: BehavioralStateContract {
///     var count: Int
///     static func applyBindingRules(to state: RulesPublisher) -> [AnyCancellable] { [] }
///     static func applyNotificationRules(to state: UIBinding<Self>) -> [NotificationToken] { [] }
///     mutating func applyRules() {}
/// }
///
/// @ManagedState var state = MyState(count: 0)
/// $state.publisher
///     .sink { print("Updated count:", $0.new.count) }
///     .store(in: &cancellables)
/// ```
@dynamicMemberLookup
@dynamicCallable
@propertyWrapper
public final class ManagedState<Value: BehavioralStateContract> {
    /// Internal subject used to emit value changes to observers.
    ///
    /// This subject drives the `publisher` and emits a `Change<Value>` when the wrapped model value changes.
    /// Duplicate values are filtered using `Equatable`.
    private let valueSubject: CurrentValueSubject<DiffedValue<Value>, Failure>
    /// Internal subject used to emit rule changes to observers.
    ///
    /// This subject drives rule evaluation and emits changes when the wrapped model value changes.
    private let rulesSubject: CurrentValueSubject<DiffedValue<Value>, Failure>

    /// The internal stored value being managed.
    private var innerValue: Value
    /// The locking mechanism used for thread safety.
    private let lock: NSLocking

    /// The current model value being managed.
    ///
    /// Assigning a new value triggers rule evaluation and emits changes to subscribers.
    /// If the value is equal to the existing one, no event is emitted.
    public var wrappedValue: Value {
        get {
            lock.withLock {
                return innerValue
            }
        }
        set {
            lock.withLock {
                if innerValue == newValue {
                    return
                }

                send(.init(old: innerValue, new: newValue, isInitial: false))
            }
        }
    }

    /// Accesses the property wrapper instance for binding or observing capabilities.
    ///
    /// Use this projected property (`$state`) to access Combine-based observation tools.
    ///
    /// ### Example
    /// ```swift
    /// $state.publisher
    ///     .sink { print($0) }
    ///     .store(in: &bag)
    /// ```
    public var projectedValue: ManagedState<Value> {
        return self
    }

    /// Array of cancellable subscriptions for binding rules.
    private var bindingRules: [AnyCancellable] = []
    /// Array of notification tokens for external event rules.
    private var notificationRules: [Any] = []

    /// Creates a new managed state wrapper with the specified initial value.
    ///
    /// This initializer also sets up all declared binding and notification rules and emits an initial change.
    ///
    /// - Parameter wrappedValue: The initial value to be managed.
    ///
    /// ### Example
    /// ```swift
    /// @ManagedState var model = MyModel()
    /// ```
    public init(wrappedValue: Value, lock: ManagedStateLock? = nil) {
        self.innerValue = wrappedValue

        switch lock ?? ManagedStateDefaultLock {
        case .absent:
            self.lock = AbsentLock()
        case .synced:
            self.lock = NSRecursiveLock()
        case .custom(let nSLocking):
            self.lock = nSLocking
        }
        self.prevValues = .init(old: nil, new: wrappedValue, isInitial: true)

        // initial `observe`
        @UIState
        var bindable = wrappedValue
        self.valueSubject = .init(.init(old: nil, binding: $bindable()))
        self.rulesSubject = .init(.init(old: nil, binding: $bindable()))

        // create rules
        notificationRules += createAnyRules($bindable())
        bindingRules += createBindingRules()

        self.lock.withLock {
            // send initial state
            send(.init(old: wrappedValue, new: bindable, isInitial: true))
        }
    }

    /// A publisher that emits only distinct changes to the wrapped value.
    ///
    /// Use this publisher to observe meaningful state transitions.
    ///
    /// ### Example
    /// ```swift
    /// $state.publisher
    ///     .sink { diff in print("Changed:", diff) }
    ///     .store(in: &cancellables)
    /// ```
    public lazy var diffedPublisher: AnyPublisher<DiffedValue<Value>, Failure> = {
        return valueSubject
            .removeDuplicates()
            .eraseToAnyPublisher()
    }()

    /// A publisher that emits only the new values when the wrapped value changes.
    ///
    /// Use this publisher to observe the current value without the diff information.
    ///
    /// ### Example
    /// ```swift
    /// $state.publisher
    ///     .sink { newValue in print("New value:", newValue) }
    ///     .store(in: &cancellables)
    /// ```
    public lazy var publisher: AnyPublisher<Value, Failure> = {
        return valueSubject
            .map(\.new)
            .removeDuplicates()
            .eraseToAnyPublisher()
    }()

    /// Atomically updates the managed state using a closure to prevent race conditions.
    ///
    /// This method ensures that read-modify-write operations are atomic and thread-safe.
    /// All operations within the closure are executed under a single lock, preventing
    /// race conditions in concurrent code.
    ///
    /// - Parameter block: A closure that receives an inout reference to the current value.
    ///
    /// ### Example
    /// ```swift
    /// state.withLock { value in
    ///     value.count += 1
    ///     value.lastUpdated = Date()
    /// }
    /// ```
    public func withLock(_ block: (inout Value) -> Void) {
        lock.withLock {
            var newValue = innerValue
            block(&newValue)

            if innerValue != newValue {
                send(.init(old: innerValue, new: newValue, isInitial: false))
            }
        }
    }

    /// Creates notification rules for the managed state.
    ///
    /// This method delegates to the `applyAnyRules` method of the wrapped value type.
    @AnyTokenBuilder<Any>
    private func createAnyRules(_ bindable: UIBinding<Value>) -> [Any] {
        Value.applyAnyRules(to: bindable)
    }

    /// Creates binding rules for the managed state.
    ///
    /// This method delegates to the `applyBindingRules` method of the wrapped value type.
    @SubscriptionBuilder
    private func createBindingRules() -> [AnyCancellable] {
        Value.applyBindingRules(to: rulesSubject.eraseToAnyPublisher())
    }

    /// The previous values for change tracking.
    private var prevValues: PairedValue<Value>

    /// Sends a value change if it represents a meaningful update.
    ///
    /// - Parameter values: The paired old and new values to potentially send.
    private func send(_ values: PairedValue<Value>) {
        guard values.isInitial || values.old != values.new else {
            return
        }

        prevValues = values

        applyRules(with: values)
    }

    /// Applies business rules to the state and handles cyclic dependency detection.
    ///
    /// - Parameter values: The paired old and new values to process.
    private func applyRules(with values: PairedValue<Value>) {
        var counter = 0
        var pair: PairedValue<Value> = values
        repeat {
            pair = modify(pair)
            counter += 1
        } while pair.old != pair.new && counter < ManagedStateCyclicDependencyMaxDepth

        assert(ManagedStateCyclicDependencyWarning || counter < 100, "Cyclic dependency detected in state rules")

        guard values.isInitial || values.old != pair.new else {
            return
        }

        innerValue = pair.new
        valueSubject.send(.init(old: values.old, binding: self()))
    }

    /// Modifies the state by applying business rules and notifying rule subscribers.
    ///
    /// - Parameter values: The paired old and new values to modify.
    /// - Returns: The modified paired values after applying rules.
    private func modify(_ values: PairedValue<Value>) -> PairedValue<Value> {
        @UIState
        var bindable: Value = values.new
        bindable.applyRules()

        let changes = DiffedValue(old: values.old, binding: $bindable())
        rulesSubject.send(changes)

        return .init(old: values.new, new: bindable)
    }
}

extension ManagedState: SafeBinding {}

extension ManagedState: Combine.Publisher {
    public typealias Output = DiffedValue<Value>
    public typealias Failure = Never

    /// Attaches the specified subscriber to receive diffed value changes.
    ///
    /// This method forwards the subscription to the internal `diffedPublisher`,
    /// which emits `DiffedValue` containing both old and new values.
    ///
    /// - Parameter subscriber: The subscriber to attach to this publisher.
    public func receive<S>(subscriber: S) where S: Subscriber, Never == S.Failure, DiffedValue<Value> == S.Input {
        diffedPublisher.receive(subscriber: subscriber)
    }

    /// Attaches the specified subscriber to receive only new values.
    ///
    /// This method forwards the subscription to the internal `publisher`,
    /// which emits only the new values without the old values.
    ///
    /// - Parameter subscriber: The subscriber to attach to this publisher.
    public func receive<S>(subscriber: S) where S: Subscriber, Never == S.Failure, Value == S.Input {
        publisher.receive(subscriber: subscriber)
    }
}

public extension ManagedState {
    /// Provides a two-way binding interface for a property of the managed value using dynamic member lookup.
    ///
    /// Use this subscript to bind UI components to individual properties within the wrapped state.
    ///
    /// - Parameter keyPath: A writable key path to a property of the wrapped value.
    /// - Returns: A `UIBinding` representing the two-way binding for the specified property.
    ///
    /// ### Example
    /// ```swift
    /// $state.username.wrappedValue = "new_username"
    /// ```
    subscript<V>(dynamicMember keyPath: WritableKeyPath<Value, V>) -> UIBinding<V> {
        return observe(keyPath)
    }

    /// Accesses and modifies properties of the wrapped value using dynamic member lookup.
    ///
    /// This subscript allows direct interaction with the stored value as if it were a normal instance.
    ///
    /// ⚠️ **Thread Safety**: While individual get/set operations are thread-safe, compound operations
    /// like `state.count += 1` are NOT atomic and may cause race conditions in concurrent code.
    /// Use direct assignment for thread-safe updates: `state.count = newValue`.
    ///
    /// - Parameter keyPath: A writable key path to a property of the wrapped value.
    /// - Returns: The current value at the specified key path.
    ///
    /// ### Example
    /// ```swift
    /// state.username = "John"  // ✅ Thread-safe
    /// print(state.username)   // ✅ Thread-safe
    ///
    /// // ❌ NOT thread-safe in concurrent code:
    /// // state.count += 1
    ///
    /// // ✅ Thread-safe alternative:
    /// state.count = state.count + 1
    /// ```
    subscript<V>(dynamicMember keyPath: WritableKeyPath<Value, V>) -> V {
        get {
            wrappedValue[keyPath: keyPath]
        }
        set {
            wrappedValue[keyPath: keyPath] = newValue
        }
    }

    subscript<V>(dynamicMember keyPath: KeyPath<Value, V>) -> V {
        wrappedValue[keyPath: keyPath]
    }

    /// Dynamically calls the managed state to return a binding to the entire value.
    ///
    /// This method enables callable syntax for accessing the full binding.
    ///
    /// - Parameter withArguments: Unused arguments array.
    /// - Returns: A `UIBinding` for the entire managed value.
    ///
    /// ### Example
    /// ```swift
    /// @ManagedState var user = User(name: "Alice", age: 30)
    ///
    /// // Get binding to entire user object
    /// let userBinding = user()
    /// userBinding.wrappedValue.name = "Bob"
    ///
    /// // Observe changes to entire user
    /// user().sink { user in
    ///     print("User updated: \(user.name), \(user.age)")
    /// }.store(in: &cancellables)
    /// ```
    func dynamicallyCall(withArguments: [Any]) -> UIBinding<Value> {
        return observe()
    }

    /// Dynamically calls the managed state with a key path to return a nested binding.
    ///
    /// This method enables callable syntax for accessing nested property bindings.
    ///
    /// - Parameter args: An array containing a single writable key path.
    /// - Returns: A `UIBinding` for the nested property.
    ///
    /// ### Example
    /// ```swift
    /// @ManagedState var user = User(name: "Alice", age: 30)
    ///
    /// // Get binding to specific property
    /// let nameBinding = user(\.name)
    /// nameBinding.wrappedValue = "Bob"
    ///
    /// // Observe changes to specific property
    /// user(\.age).sink { age in
    ///     print("Age changed to: \(age)")
    /// }.store(in: &cancellables)
    /// ```
    func dynamicallyCall<T>(withArguments args: [WritableKeyPath<Value, T>]) -> UIBinding<T> {
        guard let keyPath = args.first else {
            fatalError("At least one key path argument is required")
        }

        return observe(keyPath)
    }
}

extension ManagedState: Equatable where Value: Equatable {
    public static func ==(lhs: ManagedState<Value>, rhs: ManagedState<Value>) -> Bool {
        return lhs.wrappedValue == rhs.wrappedValue
    }
}

extension ManagedState: Hashable where Value: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(wrappedValue)
    }
}

extension ManagedState: CustomStringConvertible where Value: CustomStringConvertible {
    /// A textual representation of the managed value.
    ///
    /// This property forwards the description from the managed value,
    /// providing a string representation suitable for display purposes.
    ///
    /// - Returns: A string representation of the managed value.
    public var description: String {
        return wrappedValue.description
    }
}

extension ManagedState: CustomDebugStringConvertible where Value: CustomDebugStringConvertible {
    /// A textual representation of the managed value, suitable for debugging.
    ///
    /// This property forwards the debug description from the managed value,
    /// providing detailed information useful for debugging purposes.
    ///
    /// - Returns: A debug string representation of the managed value.
    public var debugDescription: String {
        return wrappedValue.debugDescription
    }
}

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
extension ManagedState: CustomLocalizedStringResourceConvertible where Value: CustomLocalizedStringResourceConvertible {
    /// A localized string resource representation of the managed value.
    ///
    /// This property forwards the localized string resource from the managed value,
    /// enabling localization support for the managed state.
    ///
    /// - Returns: A localized string resource representation of the managed value.
    public var localizedStringResource: LocalizedStringResource {
        return wrappedValue.localizedStringResource
    }
}

extension ManagedState: @unchecked Sendable {}

/// Represents a transition between two values of the same type.
///
/// `PairedValue` is used internally to track state changes. It captures both the old and new values,
/// and whether the transition was the initial emission.
///
/// - Parameters:
///   - old: The previous value, or `nil` if this is the first emission.
///   - new: The new value after the change.
///   - isInitial: A Boolean value indicating whether this is the initial emission.
///
/// ### Example
/// ```swift
/// let diff = PairedValue(old: nil, new: state, isInitial: true)
/// print("Initial:", diff.new)
/// ```
private struct PairedValue<Value> {
    let old: Value?
    let new: Value
    var isInitial: Bool = false
}

extension PairedValue: CustomDebugStringConvertible {
    /// A debug-friendly textual representation of the paired value.
    ///
    /// Displays both the old and new value states for inspection in logs or consoles.
    var debugDescription: String {
        "DiffedValue(old: \(String(describing: old)), new: \(new))"
    }
}

/// A no-op locking mechanism that performs no synchronization.
///
/// Use `AbsentLock` in single-threaded or testing contexts where locking is not needed.
private final class AbsentLock: NSLocking {
    /// No-op lock.
    func lock() {}

    /// No-op unlock.
    func unlock() {}
}
