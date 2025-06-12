import Combine
import Foundation

/// A property wrapper that manages observable and bindable state conforming to `BehavioralStateContract`.
///
/// `ManagedState` enables reactive state updates, binding rule application, and publisher-based observation.
/// This wrapper is especially useful for ViewModel-style architectures and dynamic UI synchronization.
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
///
/// $state.publisher
///     .sink { change in
///         print("State changed from \(change.old?.count ?? 0) to \(change.new.count)")
///     }
///     .store(in: &cancellables)
/// ```
@dynamicMemberLookup
@propertyWrapper
public final class ManagedState<Value: BehavioralStateContract> {
    /// Internal subject used to emit value changes to observers.
    ///
    /// This subject drives the `publisher` and emits a `Change<Value>` when the wrapped model value changes.
    /// Duplicate values are filtered using `Equatable`.
    private lazy var valueSubject: CurrentValueSubject<DiffedValue<Value>, Failure> = CurrentValueSubject(.init(old: nil, new: observe()))
    private let rulesSubject: EventSubject<DiffedValue<Value>> = .init()

    /// receiving oldValue
    private lazy var changeEventStream: EventSubject<PairedValue<Value>> = .init()
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

    /// The projected value used to access binding and observation capabilities.
    ///
    /// Use this property (prefixed with `$`) to observe or bind to the state.
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

        bindingRules += applyBindingRules()
        notificationRules += applyAnyRules()

        changeEventStream.send(.init(old: wrappedValue, new: innerValue, isInitial: true))
    }

    /// A publisher that emits distinct changes to the managed value.
    ///
    /// The publisher emits `DiffedValue<Value>` every time the state changes and is not equal to the previous value.
    ///
    /// ### Example
    /// ```swift
    /// $state.publisher
    ///     .sink { print("State updated:", $0) }
    ///     .store(in: &cancellables)
    /// ```
    public lazy var publisher: AnyPublisher<DiffedValue<Value>, Failure> = {
        return valueSubject
            .removeDuplicates()
            .eraseToAnyPublisher()
    }()

    @AnyTokenBuilder<Any>
    private func applyAnyRules() -> [Any] {
        Value.applyAnyRules(to: observe())
    }

    @SubscriptionBuilder
    private func applyBindingRules() -> [AnyCancellable] {
        changeEventStream
            .removeDuplicates()
            .sink { [unowned self] new in
                applyRules(with: new)
            }

        Value.applyBindingRules(to: rulesSubject.eraseToAnyPublisher())
    }

    /// Handles incoming actions by mutating and reassigning the wrapped value.
    ///
    /// Applies the specified action to the state, performs post-processing, and emits changes via the subject.
    ///
    /// - Parameter action: The internal `Action` enum representing a root or property change.
    private func applyRules(with values: PairedValue<Value>) {
        func shouldEmit(old: Value?, new: Value) -> Bool {
            return values.isInitial || (!values.isInitial && old != new)
        }

        guard shouldEmit(old: values.old, new: values.new) else {
            return
        }

        @UIState
        var bindable: Value = values.new
        bindable.applyRules()

        let changes = DiffedValue(old: innerValue, new: $bindable.observe())
        rulesSubject.send(changes)

        guard shouldEmit(old: innerValue, new: bindable) else {
            return
        }

        innerValue = bindable
        valueSubject.send(changes)
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

    /// Attaches the specified subscriber to the state publisher.
    ///
    /// - Parameter subscriber: The subscriber to attach.
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

private struct PairedValue<Value> {
    let old: Value?
    let new: Value
    let isInitial: Bool
}

extension PairedValue: CustomDebugStringConvertible {
    var debugDescription: String {
        "DiffedValue(old: \(String(describing: old)), new: \(new))"
    }
}

extension PairedValue: Equatable where Value: Equatable {}
extension PairedValue: Sendable where Value: Sendable {}
