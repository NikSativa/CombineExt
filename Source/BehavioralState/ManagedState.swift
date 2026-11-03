import Combine
import Foundation
import Observation

/// Enables the assertion that detects a cyclic dependency in state rules.
///
/// The rules converge when a rule pass does not change the value.
/// If the value is `true` and the rules do not converge within `ManagedStateCyclicDependencyMaxDepth` passes, a debug build stops with an assertion failure.
/// If the value is `false`, the rules stop after `ManagedStateCyclicDependencyMaxDepth` passes without an assertion failure.
///
/// - Note: The default value is `true`.
///
/// ### Example
/// ```swift
/// ManagedStateCyclicDependencyWarning = false
/// ```
public nonisolated(unsafe) var ManagedStateCyclicDependencyWarning: Bool = true
/// The maximum number of rule passes for one change of the managed value.
///
/// `ManagedState` stops the rule passes at this limit, also when the rules do not converge. The limit prevents an infinite loop.
/// If the rules do not converge at this limit, `ManagedStateCyclicDependencyWarning` controls the assertion failure.
///
/// - Note: The default value is `100`.
///
/// ### Example
/// ```swift
/// ManagedStateCyclicDependencyMaxDepth = 50
/// ```
public nonisolated(unsafe) var ManagedStateCyclicDependencyMaxDepth: Int = 100
/// The lock type that `ManagedState` uses when the initializer gets no lock.
///
/// Set `.absent`, `.synced`, or `.custom(_:)` to change the lock type of all new instances.
/// The change has no effect on existing instances.
///
/// - Note: The default value is `.synced`.
///
/// ### Example
/// ```swift
/// ManagedStateDefaultLock = .absent
/// @ManagedState var model = MyModel()
/// ```
public nonisolated(unsafe) var ManagedStateDefaultLock: ManagedStateLock = .synced

extension ManagedState: ObservableObject {
    /// A publisher that emits before each change of the managed value.
    ///
    /// The publisher emits one time for each change. A subscriber that reads the state in the handler gets the old value.
    /// The publisher does not emit when a subscriber subscribes, and it does not emit for an equal value.
    public var objectWillChange: AnyPublisher<Void, Never> {
        return objectWillChangeSubject.eraseToAnyPublisher()
    }
}

/// A property wrapper that manages a value and applies the rules of `BehavioralStateContract`.
///
/// Each change of the managed value runs the rules of the value type.
/// Then `ManagedState` stores the final result and notifies the subscribers and observers.
/// `ManagedState` supports Combine, `ObservableObject`, and the Observation framework. Use it in a ViewModel for SwiftUI or UIKit.
///
/// The type supports `@dynamicMemberLookup` for direct access to the properties of the managed value.
///
/// - Important: A single read or a single write is thread-safe. A compound operation, such as `state.count += 1`, is not atomic.
///   Use `withLock(_:)` for a read-modify-write operation.
///
/// ### Example
/// ```swift
/// struct MyState: BehavioralStateContract {
///     var count: Int = 0
///     mutating func applyRules() {}
///     @SubscriptionBuilder
///     static func applyBindingRules(to state: RulesPublisher) -> [AnyCancellable] { [] }
///     @AnyTokenBuilder<Any>
///     static func applyAnyRules(to state: UIBinding<Self>) -> [Any] { [] }
/// }
///
/// @ManagedState var state = MyState()
/// $state
///     .sink { print("Updated count:", $0.new.count) }
///     .store(in: &cancellables)
/// state.count += 1
/// ```
@dynamicMemberLookup
@dynamicCallable
@propertyWrapper
public final class ManagedState<Value: BehavioralStateContract> {
    /// The subject that sends each change of the managed value.
    ///
    /// `publisher` and `diffedPublisher` use this subject and remove duplicate values.
    private let valueSubject: CurrentValueSubject<DiffedValue<Value>, Failure>
    /// The subject that sends a local copy of the value to the binding rules on each rule pass.
    private let rulesSubject: CurrentValueSubject<DiffedValue<Value>, Failure>
    private let objectWillChangeSubject = PassthroughSubject<Void, Never>()

    /// The managed value. The lock protects it.
    private var innerValue: Value
    /// The lock that protects the managed value.
    private let lock: NSLocking
    /// The `ObservationRegistrar` that tracks reads and changes of `wrappedValue`.
    ///
    /// The value is `nil` on platforms without the Observation framework.
    /// The type is `Any?` because a stored property cannot have a type that is not available on every supported platform.
    private let observationRegistrar: Any?

    /// The managed value.
    ///
    /// A write of a different value runs the rules, stores the result, and notifies the subscribers and observers.
    /// A write of an equal value has no effect.
    /// A read registers an Observation access.
    public var wrappedValue: Value {
        get {
            registerObservationAccess()
            return lock.withLock {
                return innerValue
            }
        }
        set {
            lock.withLock {
                if innerValue == newValue {
                    return
                }

                applyRules(with: .init(old: innerValue, new: newValue, isInitial: false))
            }
        }
    }

    /// The state itself, available as `$state`.
    ///
    /// Use it to get publishers and bindings.
    ///
    /// ### Example
    /// ```swift
    /// $state.publisher
    ///     .sink { print($0) }
    ///     .store(in: &cancellables)
    /// ```
    public var projectedValue: ManagedState<Value> {
        return self
    }

    /// The subscriptions of the binding rules.
    private var bindingRules: [AnyCancellable] = []
    /// The tokens of the rules from `applyAnyRules(to:)`.
    private var notificationRules: [Any] = []

    /// Creates a state with an initial value.
    ///
    /// The initializer creates the rules of the value type and runs the rules on the initial value.
    ///
    /// - Parameters:
    ///   - wrappedValue: The initial value.
    ///   - lock: The lock type. If the value is `nil`, the state uses `ManagedStateDefaultLock`.
    ///
    /// ### Example
    /// ```swift
    /// @ManagedState var model = MyModel()
    /// @ManagedState(lock: .absent) var localModel = MyModel()
    /// ```
    public init(wrappedValue: Value, lock: ManagedStateLock? = nil) {
        self.innerValue = wrappedValue

        if #available(iOS 17, macOS 14, tvOS 17, watchOS 10, visionOS 1, *) {
            self.observationRegistrar = ObservationRegistrar()
        } else {
            self.observationRegistrar = nil
        }

        switch lock ?? ManagedStateDefaultLock {
        case .absent:
            self.lock = AbsentLock()
        case .synced:
            self.lock = NSRecursiveLock()
        case let .custom(customLock):
            self.lock = customLock
        }

        @UIState
        var initialValue = wrappedValue
        let valueSubject = CurrentValueSubject<DiffedValue<Value>, Failure>(.init(old: nil, binding: $initialValue()))
        self.valueSubject = valueSubject
        self.diffedPublisher = valueSubject
            .removeUnchangedAfterFirst()
            .eraseToAnyPublisher()
        self.publisher = valueSubject
            .map(\.new)
            .removeDuplicates()
            .eraseToAnyPublisher()
        self.rulesSubject = .init(.init(old: nil, binding: $initialValue()))

        notificationRules += createAnyRules(unretainedBinding(fallback: wrappedValue))
        bindingRules += createBindingRules()

        self.lock.withLock {
            applyRules(with: .init(old: wrappedValue, new: initialValue, isInitial: true))
        }
    }

    /// A publisher that emits each change of the managed value as a `DiffedValue`.
    ///
    /// The `old` property contains the value before the change. The `new` property reads the current value of the state.
    /// A new subscriber immediately gets the current value.
    ///
    /// ### Example
    /// ```swift
    /// $state.diffedPublisher
    ///     .sink { diff in print("Changed:", diff) }
    ///     .store(in: &cancellables)
    /// ```
    public let diffedPublisher: AnyPublisher<DiffedValue<Value>, Failure>

    /// A publisher that emits the managed value after each change.
    ///
    /// A new subscriber immediately gets the current value. The publisher removes duplicate values.
    ///
    /// ### Example
    /// ```swift
    /// $state.publisher
    ///     .sink { newValue in print("New value:", newValue) }
    ///     .store(in: &cancellables)
    /// ```
    public let publisher: AnyPublisher<Value, Failure>

    /// Changes the managed value atomically.
    ///
    /// The closure gets a copy of the current value. The state holds the lock during the closure and the rules.
    /// If the closure changes the value, the state runs the rules on the result and notifies the subscribers and observers one time.
    ///
    /// - Parameter block: The closure that changes the value.
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
                applyRules(with: .init(old: innerValue, new: newValue, isInitial: false))
            }
        }
    }

    /// Creates the rules from `applyAnyRules(to:)` of the value type.
    private func createAnyRules(_ bindable: UIBinding<Value>) -> [Any] {
        return Value.applyAnyRules(to: bindable)
    }

    /// Creates the binding rules from `applyBindingRules(to:)` of the value type.
    private func createBindingRules() -> [AnyCancellable] {
        return Value.applyBindingRules(to: rulesSubject.eraseToAnyPublisher())
    }

    /// Runs the rule passes until the rules converge, stores the result, and notifies the subscribers and observers.
    ///
    /// Each rule pass changes a local copy of the value. The method stores only the final result and notifies one time.
    /// If the change is not initial and the result is equal to the old value, the method does nothing.
    ///
    /// - Parameter values: The old value and the new value of the change.
    private func applyRules(with values: PairedValue<Value>) {
        var counter = 0
        var pair: PairedValue<Value> = values
        repeat {
            pair = applyRulesOnce(pair)
            counter += 1
        } while pair.old != pair.new && counter < ManagedStateCyclicDependencyMaxDepth

        assert(!ManagedStateCyclicDependencyWarning || pair.old == pair.new, "Cyclic dependency detected in state rules")

        guard values.isInitial || values.old != pair.new else {
            return
        }

        if values.isInitial {
            innerValue = pair.new
        } else {
            objectWillChangeSubject.send()
            withObservationMutation {
                innerValue = pair.new
            }
        }
        valueSubject.send(.init(old: values.old, binding: unretainedBinding(fallback: pair.new)))
    }

    private func unretainedBinding(fallback: Value) -> UIBinding<Value> {
        return .init(publisher: diffedPublisher) { [weak self] in
            return self?.wrappedValue ?? fallback
        } set: { [weak self] newValue in
            self?.wrappedValue = newValue
        }
    }

    /// Registers a read of `wrappedValue` with the Observation framework.
    ///
    /// The getter calls this method before it takes the lock.
    private func registerObservationAccess() {
        guard #available(iOS 17, macOS 14, tvOS 17, watchOS 10, visionOS 1, *),
              let registrar = observationRegistrar as? ObservationRegistrar else {
            return
        }

        registrar.access(self, keyPath: \.wrappedValue)
    }

    /// Runs a change of the managed value and notifies Observation observers about it.
    ///
    /// The observers receive `willSet` before the change and `didSet` after it, as with the `@Observable` macro.
    /// An observer that reads `wrappedValue` in `willSet` gets the old value.
    /// `applyRules(with:)` calls this method while it holds the lock, so an observer that reads `wrappedValue` needs a recursive lock.
    ///
    /// - Parameter mutation: The closure that changes the managed value.
    private func withObservationMutation(_ mutation: () -> Void) {
        guard #available(iOS 17, macOS 14, tvOS 17, watchOS 10, visionOS 1, *),
              let registrar = observationRegistrar as? ObservationRegistrar else {
            mutation()
            return
        }

        registrar.withMutation(of: self, keyPath: \.wrappedValue, mutation)
    }

    /// Runs one rule pass on a local copy of the value.
    ///
    /// The method calls `applyRules()` on the copy and sends the copy to the binding rules.
    ///
    /// - Parameter values: The input of the rule pass.
    /// - Returns: A pair of the input and the result of the rule pass.
    private func applyRulesOnce(_ values: PairedValue<Value>) -> PairedValue<Value> {
        @UIState
        var bindable: Value = values.new
        bindable.applyRules()

        let changes = DiffedValue(old: values.old, binding: $bindable())
        rulesSubject.send(changes)

        return .init(old: values.new, new: bindable)
    }
}

extension ManagedState: SafeBinding {}

/// Makes `ManagedState` observable with the Observation framework.
///
/// SwiftUI and `withObservationTracking(_:onChange:)` track reads of `wrappedValue` and of its dynamic members.
/// Every change of the managed value notifies the observers one time. A change to an equal value does not notify them.
/// The observers receive the notification before the managed value changes, as with the `@Observable` macro.
///
/// ### Example
/// ```swift
/// @Observable
/// final class ViewModel {
///     @ObservationIgnored
///     @ManagedState
///     private var viewState = AppState()
///
///     var state: AppState {
///         return viewState
///     }
/// }
/// ```
@available(iOS 17, macOS 14, tvOS 17, watchOS 10, visionOS 1, *)
extension ManagedState: Observation.Observable {}

extension ManagedState: Combine.Publisher {
    public typealias Output = DiffedValue<Value>
    public typealias Failure = Never

    /// Attaches a subscriber that receives each change as a `DiffedValue`.
    ///
    /// The method forwards the subscriber to `diffedPublisher`.
    ///
    /// - Parameter subscriber: The subscriber to attach.
    public func receive<S>(subscriber: S) where S: Subscriber, Never == S.Failure, DiffedValue<Value> == S.Input {
        diffedPublisher.receive(subscriber: subscriber)
    }

    /// Attaches a subscriber that receives the managed value after each change.
    ///
    /// The method forwards the subscriber to `publisher`.
    ///
    /// - Parameter subscriber: The subscriber to attach.
    public func receive<S>(subscriber: S) where S: Subscriber, Never == S.Failure, Value == S.Input {
        publisher.receive(subscriber: subscriber)
    }
}

public extension ManagedState {
    /// Returns a two-way binding to a property of the managed value.
    ///
    /// Use the binding to connect a UI component to one property.
    ///
    /// - Parameter keyPath: A writable key path to a property of the managed value.
    /// - Returns: A binding to the property.
    ///
    /// ### Example
    /// ```swift
    /// $state.username.wrappedValue = "new_username"
    /// ```
    subscript<V>(dynamicMember keyPath: WritableKeyPath<Value, V>) -> UIBinding<V> {
        return observe(keyPath)
    }

    /// Reads or writes a property of the managed value.
    ///
    /// A write changes the managed value and runs the rules.
    ///
    /// - Important: A single read or a single write is thread-safe. A compound operation, such as `state.count += 1`, is not atomic.
    ///   Use `withLock(_:)` for a read-modify-write operation.
    ///
    /// - Parameter keyPath: A writable key path to a property of the managed value.
    /// - Returns: The current value of the property.
    ///
    /// ### Example
    /// ```swift
    /// state.username = "John"
    /// print(state.username)
    ///
    /// state.withLock { value in
    ///     value.count += 1
    /// }
    /// ```
    subscript<V>(dynamicMember keyPath: WritableKeyPath<Value, V>) -> V {
        get {
            return wrappedValue[keyPath: keyPath]
        }
        set {
            wrappedValue[keyPath: keyPath] = newValue
        }
    }

    /// Reads a read-only property of the managed value.
    ///
    /// - Parameter keyPath: A key path to a property of the managed value.
    /// - Returns: The current value of the property.
    subscript<V>(dynamicMember keyPath: KeyPath<Value, V>) -> V {
        return wrappedValue[keyPath: keyPath]
    }

    /// Returns a two-way binding to the managed value for the call syntax `$state()`.
    ///
    /// - Parameter withArguments: The call arguments. The method ignores them.
    /// - Returns: A binding to the managed value.
    ///
    /// ### Example
    /// ```swift
    /// struct User: BehavioralStateContract {
    ///     var name: String
    ///     var age: Int
    ///     mutating func applyRules() {}
    ///     @SubscriptionBuilder
    ///     static func applyBindingRules(to state: RulesPublisher) -> [AnyCancellable] { [] }
    ///     @AnyTokenBuilder<Any>
    ///     static func applyAnyRules(to state: UIBinding<Self>) -> [Any] { [] }
    /// }
    ///
    /// @ManagedState var user = User(name: "Alice", age: 30)
    ///
    /// let userBinding = $user()
    /// userBinding.wrappedValue.name = "Bob"
    ///
    /// $user().sink { user in
    ///     print("User updated: \(user.name), \(user.age)")
    /// }.store(in: &cancellables)
    /// ```
    func dynamicallyCall(withArguments: [Any]) -> UIBinding<Value> {
        return observe()
    }

    /// Returns a two-way binding to a property of the managed value for the call syntax `$state(\.property)`.
    ///
    /// The method uses only the first key path. If `args` is empty, the method stops the program with a fatal error.
    ///
    /// - Parameter args: The key paths of the call.
    /// - Returns: A binding to the property.
    ///
    /// ### Example
    /// ```swift
    /// struct User: BehavioralStateContract {
    ///     var name: String
    ///     var age: Int
    ///     mutating func applyRules() {}
    ///     @SubscriptionBuilder
    ///     static func applyBindingRules(to state: RulesPublisher) -> [AnyCancellable] { [] }
    ///     @AnyTokenBuilder<Any>
    ///     static func applyAnyRules(to state: UIBinding<Self>) -> [Any] { [] }
    /// }
    ///
    /// @ManagedState var user = User(name: "Alice", age: 30)
    ///
    /// let nameBinding = $user(\.name)
    /// nameBinding.wrappedValue = "Bob"
    ///
    /// $user(\.age).sink { age in
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
    /// Compares the managed values of two instances.
    ///
    /// Two different instances are equal when their managed values are equal.
    public static func ==(lhs: ManagedState<Value>, rhs: ManagedState<Value>) -> Bool {
        return lhs.wrappedValue == rhs.wrappedValue
    }
}

extension ManagedState: Hashable where Value: Hashable {
    /// Hashes the current managed value.
    ///
    /// The hash value changes when the managed value changes.
    /// Do not change the managed value while the instance is an element of a `Set` or a key of a `Dictionary`.
    /// After such a change, the collection cannot find the instance.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(wrappedValue)
    }
}

extension ManagedState: CustomStringConvertible where Value: CustomStringConvertible {
    /// The description of the managed value.
    public var description: String {
        return wrappedValue.description
    }
}

extension ManagedState: CustomDebugStringConvertible where Value: CustomDebugStringConvertible {
    /// The debug description of the managed value.
    public var debugDescription: String {
        return wrappedValue.debugDescription
    }
}

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
extension ManagedState: CustomLocalizedStringResourceConvertible where Value: CustomLocalizedStringResourceConvertible {
    /// The localized string resource of the managed value.
    public var localizedStringResource: LocalizedStringResource {
        return wrappedValue.localizedStringResource
    }
}

extension ManagedState: @unchecked Sendable {}

/// A change from an old value to a new value.
///
/// `ManagedState` uses this type for the input and the result of a rule pass.
/// `isInitial` is `true` only for the change that the initializer makes.
private struct PairedValue<Value> {
    let old: Value?
    let new: Value
    var isInitial: Bool = false
}

/// A lock that does nothing.
///
/// `ManagedState` uses this lock for `ManagedStateLock.absent`.
private final class AbsentLock: NSLocking {
    /// Does nothing.
    func lock() {}

    /// Does nothing.
    func unlock() {}
}
