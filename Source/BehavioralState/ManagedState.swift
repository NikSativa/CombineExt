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
    private let rulesSubject: CurrentValueSubject<DiffedValue<Value>, Failure>

    private var innerValue: Value
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

    private var bindingRules: [AnyCancellable] = []
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
        self.valueSubject = .init(.init(old: nil, new: $bindable()))
        self.rulesSubject = .init(.init(old: nil, new: $bindable()))

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
    public lazy var publisher: AnyPublisher<DiffedValue<Value>, Failure> = {
        return valueSubject
            .removeDuplicates()
            .eraseToAnyPublisher()
    }()

    @AnyTokenBuilder<Any>
    private func createAnyRules(_ bindable: UIBinding<Value>) -> [Any] {
        Value.applyAnyRules(to: bindable)
    }

    @SubscriptionBuilder
    private func createBindingRules() -> [AnyCancellable] {
        Value.applyBindingRules(to: rulesSubject.eraseToAnyPublisher())
    }

    private var prevValues: PairedValue<Value>
    private func send(_ values: PairedValue<Value>) {
        guard values.isInitial || values.old != values.new else {
            return
        }

        prevValues = values

        applyRules(with: values)
    }

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
        valueSubject.send(.init(old: values.old, new: self()))
    }

    private func modify(_ values: PairedValue<Value>) -> PairedValue<Value> {
        @UIState
        var bindable: Value = values.new
        bindable.applyRules()

        let changes = DiffedValue(old: values.old, new: $bindable())
        rulesSubject.send(changes)

        return .init(old: values.new, new: bindable)
    }
}

extension ManagedState: SafeBinding {}

extension ManagedState: Combine.Publisher {
    public typealias Output = DiffedValue<Value>
    public typealias Failure = Never

    public func receive<S>(subscriber: S) where S: Subscriber, Never == S.Failure, DiffedValue<Value> == S.Input {
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
    /// - Parameter keyPath: A writable key path to a property of the wrapped value.
    /// - Returns: The current value at the specified key path.
    ///
    /// ### Example
    /// ```swift
    /// state.username = "John"
    /// print(state.username)
    /// ```
    subscript<V>(dynamicMember keyPath: WritableKeyPath<Value, V>) -> V {
        get {
            wrappedValue[keyPath: keyPath]
        }
        set {
            wrappedValue[keyPath: keyPath] = newValue
        }
    }

    func dynamicallyCall(withArguments: [Any]) -> UIBinding<Value> {
        return observe()
    }

    func dynamicallyCall<T>(withArguments args: [WritableKeyPath<Value, T>]) -> UIBinding<T> {
        guard let keyPath = args.first else {
            fatalError("At least one key path argument is required")
        }

        return observe(keyPath)
    }

    func dynamicallyCall<T>(withKeywordArguments args: KeyValuePairs<WritableKeyPath<Value, T>, T>) {
        guard let arg = args.first else {
            fatalError("At least one key path argument is required")
        }

        wrappedValue[keyPath: arg.key] = arg.value
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
    public var description: String {
        return wrappedValue.description
    }
}

extension ManagedState: CustomDebugStringConvertible where Value: CustomDebugStringConvertible {
    public var debugDescription: String {
        return wrappedValue.debugDescription
    }
}

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
extension ManagedState: CustomLocalizedStringResourceConvertible where Value: CustomLocalizedStringResourceConvertible {
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
