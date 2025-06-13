import Combine
import Foundation

/// A global flag that enables or disables cyclic dependency assertions in state rules.
///
/// When set to `true`, an assertion will be triggered if rule evaluation loops exceed a safe limit.
/// Defaults to `true`.
#if swift(>=6.0)
public nonisolated(unsafe) var ManagedStateCyclicDependencyWarning: Bool = true
/// The maximum number of times state rules may be reapplied before considering it a cyclic dependency.
///
/// Defaults to `100`. If exceeded, and `ManagedStateCyclicDependencyWarning` is `true`, an assertion is triggered.
public nonisolated(unsafe) var ManagedStateCyclicDependencyMaxDepth: Int = 100
#else
public var ManagedStateCyclicDependencyWarning: Bool = true
/// The maximum number of times state rules may be reapplied before considering it a cyclic dependency.
///
/// Defaults to `100`. If exceeded, and `ManagedStateCyclicDependencyWarning` is `true`, an assertion is triggered.
public var ManagedStateCyclicDependencyMaxDepth: Int = 100
#endif
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
@propertyWrapper
public final class ManagedState<Value: BehavioralStateContract> {
    /// Internal subject used to emit value changes to observers.
    ///
    /// This subject drives the `publisher` and emits a `Change<Value>` when the wrapped model value changes.
    /// Duplicate values are filtered using `Equatable`.
    private let valueSubject: CurrentValueSubject<DiffedValue<Value>, Failure>
    private let rulesSubject: CurrentValueSubject<DiffedValue<Value>, Failure>
    private let changeEventStream: EventSubject<PairedValue<Value>> = .init()

    private var innerValue: Value

    /// The current model value being managed.
    ///
    /// Assigning a new value triggers rule evaluation and emits changes to subscribers.
    /// If the value is equal to the existing one, no event is emitted.
    public var wrappedValue: Value {
        get {
            return innerValue
        }
        set {
            if innerValue == newValue {
                return
            }

            changeEventStream.send(.init(old: innerValue, new: newValue, isInitial: false))
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
    public init(wrappedValue: Value) {
        self.innerValue = wrappedValue

        // initial `observe`
        @UIState
        var bindable = wrappedValue
        self.valueSubject = .init(.init(old: nil, new: $bindable.observe()))
        self.rulesSubject = .init(.init(old: nil, new: $bindable.observe()))

        // create rules
        bindingRules += createBindingRules()
        notificationRules += createAnyRules()

        // send initial state
        changeEventStream.send(.init(old: wrappedValue, new: innerValue, isInitial: true))
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
    private func createAnyRules() -> [Any] {
        Value.applyAnyRules(to: observe())
    }

    @SubscriptionBuilder
    private func createBindingRules() -> [AnyCancellable] {
        changeEventStream
            .removeDuplicates()
            .sink { [unowned self] new in
                applyRules(with: new)
            }

        Value.applyBindingRules(to: rulesSubject.eraseToAnyPublisher())
    }

    private func shouldEmit(_ values: PairedValue<Value>) -> Bool {
        return values.isInitial || (!values.isInitial && values.old != values.new)
    }

    private func applyRules(with values: PairedValue<Value>) {
        guard shouldEmit(values) else {
            return
        }

        var counter = 0
        var pair: PairedValue<Value> = .init(old: innerValue, new: values.new, isInitial: values.isInitial)
        repeat {
            pair = modify(pair)
            counter += 1
        } while pair.old != pair.new && counter < ManagedStateCyclicDependencyMaxDepth

        assert(ManagedStateCyclicDependencyWarning || counter < 100, "Cyclic dependency detected in state rules")

        let newValues: PairedValue = .init(old: innerValue, new: pair.new, isInitial: values.isInitial)
        guard shouldEmit(newValues) else {
            return
        }

        innerValue = pair.new
        valueSubject.send(.init(old: values.old, new: observe()))
    }

    private func modify(_ values: PairedValue<Value>) -> PairedValue<Value> {
        @UIState
        var bindable: Value = values.new
        bindable.applyRules()

        let changes = DiffedValue(old: values.old, new: $bindable.observe())
        rulesSubject.send(changes)

        return .init(old: values.new, new: changes.new)
    }
}

/// Conformance to `SafeBinding` for type-safe UI binding access.
extension ManagedState: SafeBinding {}

/// Conformance to `Publisher` for `DiffedValue<Value>` output.
///
/// Allows the `ManagedState` to be used directly in Combine pipelines.
extension ManagedState: Combine.Publisher {
    public typealias Output = DiffedValue<Value>
    public typealias Failure = Never

    /// Attaches a Combine subscriber to receive state changes as `DiffedValue<Value>`.
    ///
    /// Conforms to Combine's `Publisher` protocol.
    ///
    /// - Parameter subscriber: A Combine subscriber to receive updates.
    ///
    /// ### Example
    /// ```swift
    /// state
    ///     .sink { print($0) }
    ///     .store(in: &bag)
    /// ```
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
}

/// A container representing a state transition from an old value to a new value.
///
/// Used internally to track and emit changes during rule application and event propagation.
///
/// - Note: If `isInitial` is `true`, this indicates the very first emission.
///
/// ### Example
/// ```swift
/// let transition = PairedValue(old: nil, new: MyModel(), isInitial: true)
/// print(transition.new)
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

/// Conforms to `Equatable` when the wrapped `Value` is `Equatable`.
///
/// Enables comparison of state transitions and filtering of redundant updates.
extension PairedValue: Equatable where Value: Equatable {}

/// Conforms to `Sendable` when the wrapped `Value` is `Sendable`.
///
/// Supports safe concurrency when `ManagedState` is used in async environments.
extension PairedValue: Sendable where Value: Sendable {}
