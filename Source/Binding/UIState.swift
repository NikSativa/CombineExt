import Combine
import Foundation
import Observation

/// A property wrapper and Combine publisher that manages reactive application state.
///
/// Use `UIState` to hold and publish value changes of any `Equatable` type.
/// It enables binding, dynamic member lookup, and diff-based state observation.
/// `UIState` supports Combine, `ObservableObject`, and the Observation framework.
///
/// The projected value gives access to the properties of the value, as `ManagedState` does:
///
/// - `state.counter` is the value of the property.
/// - `$state.counter` is a SwiftUI `Binding` to the property.
/// - `$state.ui.counter` is a `UIBinding` to the property.
/// - `$state[\.counter]` is the value of the property. With the Observation framework, this read tracks only the property.
///
/// With the Observation framework, a read of `wrappedValue` tracks the whole value.
///
/// - Important: A single read or a single write is thread-safe. A compound operation, such as `state.counter += 1`, is not atomic.
///   Use `withLock(_:)` for a read-modify-write operation.
///
/// ### Example
/// ```swift
/// struct State: Equatable {
///     var counter: Int
/// }
///
/// @UIState var state = State(counter: 0)
///
/// $state.ui.counter.sink { diff in
///     print("Counter changed to \(diff.new)")
/// }.store(in: &cancellables)
///
/// state.counter = 1
/// ```
@dynamicMemberLookup
@dynamicCallable
@propertyWrapper
public final class UIState<Value: Equatable> {
    private let storage: StateStorage<Value>
    private let subject: CurrentValueSubject<DiffedValue<Value>, Failure>
    private let objectWillChangeSubject = PassthroughSubject<Void, Never>()

    /// Creates a state with an initial value.
    ///
    /// - Parameters:
    ///   - wrappedValue: The initial value of the state.
    ///   - lock: The lock type. If the value is `nil`, the state uses `StateDefaultLock`.
    ///
    /// ### Example
    /// ```swift
    /// @UIState var counter = 0
    /// @UIState(lock: .absent) var localCounter = 0
    /// ```
    public init(wrappedValue: Value, lock: StateLock? = nil) {
        self.storage = StateStorage(value: wrappedValue, lock: lock)
        let subject = CurrentValueSubject<DiffedValue<Value>, Failure>(.init(old: nil, get: wrappedValue, set: { _ in }))
        self.subject = subject
        self.publisher = subject
            .removeUnchangedAfterFirst()
            .eraseToAnyPublisher()
        subject.value = unretainedDiffedValue(old: nil, fallback: wrappedValue)
    }

    /// The current value of the state.
    ///
    /// A write of a different value stores it and notifies the subscribers and observers.
    /// A write of an equal value has no effect.
    /// A read registers an Observation access to the whole value. An observer that reads `wrappedValue` gets a notification for each change.
    /// To track one field, read the field with `subscript(_:)`, for example `$state[\.counter]`.
    public var wrappedValue: Value {
        get {
            return storage.read()
        }
        set {
            storage.lock.withLock {
                storeAndNotify(newValue)
            }
        }
    }

    /// Returns the `UIState` wrapper itself, used with `$` syntax to access bindings and publishers.
    public var projectedValue: UIState<Value> {
        return self
    }

    /// A Combine publisher that emits distinct `DiffedValue` updates whenever the state changes.
    ///
    /// Changes are published only when the new value differs from the previous value.
    ///
    /// ### Example
    /// ```swift
    /// $state.publisher.sink { diff in
    ///     print("From \(diff.old ?? 0) to \(diff.new)")
    /// }
    /// ```
    public let publisher: AnyPublisher<DiffedValue<Value>, Failure>

    /// Changes the value atomically.
    ///
    /// The closure gets a copy of the current value. The state holds the lock during the closure.
    /// If the closure changes the value, the state stores the result and notifies the subscribers and observers one time.
    ///
    /// - Parameter block: The closure that changes the value.
    ///
    /// ### Example
    /// ```swift
    /// $state.withLock { value in
    ///     value.counter += 1
    /// }
    /// ```
    public func withLock(_ block: (inout Value) -> Void) {
        storage.lock.withLock {
            var newValue = storage.lockedValue
            block(&newValue)
            storeAndNotify(newValue)
        }
    }

    private func storeAndNotify(_ newValue: Value) {
        let oldValue = storage.lockedValue
        if oldValue == newValue {
            return
        }

        objectWillChangeSubject.send()
        storage.replaceLockedValue(with: newValue)
        subject.send(unretainedDiffedValue(old: oldValue, fallback: newValue))
    }

    private func unretainedDiffedValue(old: Value?, fallback: Value) -> DiffedValue<Value> {
        return .init(old: old,
                     get: { [weak self] in
                         return self?.wrappedValue ?? fallback
                     },
                     set: { [weak self] newValue in
                         self?.wrappedValue = newValue
                     })
    }
}

/// Makes `UIState` observable with the Observation framework.
///
/// SwiftUI and `withObservationTracking(_:onChange:)` track two kinds of reads:
///
/// - A read of `wrappedValue` tracks the whole value. Each change of the value notifies the observer.
/// - A read of a field with `subscript(_:)`, such as `$state[\.user.name]`, tracks only that field. A read through a SwiftUI binding, such as `$state.counter`, also tracks only that field.
///   A change notifies the observer only when the field gets a different value. If the type of the field is not `Equatable`, the read tracks the whole value.
///
/// One change sends one notification for the whole value and one notification for each tracked field that changes.
/// `withObservationTracking(_:onChange:)` calls `onChange` only for the first notification, so one change calls `onChange` of an observer one time.
/// A change to an equal value does not notify the observers.
/// The observers receive the notification before the value changes, as with the `@Observable` macro.
///
/// ### Example
/// ```swift
/// @Observable
/// final class ViewModel {
///     @ObservationIgnored
///     @UIState
///     private(set) var state = State(counter: 0)
/// }
///
/// struct CounterView: View {
///     let viewModel: ViewModel
///
///     var body: some View {
///         Text("\(viewModel.$state[\.counter])")
///     }
/// }
/// ```
@available(iOS 17, macOS 14, tvOS 17, watchOS 10, visionOS 1, *)
extension UIState: Observation.Observable {}

extension UIState: SafeBinding {}

extension UIState: Combine.Publisher {
    public typealias Output = DiffedValue<Value>
    public typealias Failure = Never

    /// Attaches the specified subscriber to receive value changes.
    ///
    /// - Parameter subscriber: The subscriber to register for value updates.
    public func receive<S>(subscriber: S) where S: Subscriber, Never == S.Failure, DiffedValue<Value> == S.Input {
        publisher.receive(subscriber: subscriber)
    }
}

public extension UIState {
    /// Reads a property of the value and tracks only this property with the Observation framework.
    ///
    /// The key path can contain more than one component, for example `$state[\.user.name]`. The state tracks the full key path as one field.
    /// An observer that reads the property gets a notification only when a change of the value gives the property a different value.
    /// If the type of the property is not `Equatable`, the read tracks the whole value, as a read of `wrappedValue` does.
    /// The key path can be read-only, for example a computed property of the value.
    ///
    /// - Parameter keyPath: A key path from the value to the property.
    /// - Returns: The current value of the property.
    ///
    /// ### Example
    /// ```swift
    /// @UIState var state = State(counter: 0)
    ///
    /// let counter = $state[\.counter]
    /// ```
    subscript<Field>(_ keyPath: KeyPath<Value, Field>) -> Field {
        return storage.read(keyPath)
    }

    /// A two-way binding to the value for UI components.
    ///
    /// `ui` returns a `UIBinding` to the whole value. It is the same binding as the result of `$state()`.
    /// A dynamic member of this binding always returns a `UIBinding` to a property. For example, `$state.ui.counter` is a `UIBinding<Int>`.
    ///
    /// Use `ui` to give one property to a component that reads the property, changes it, and subscribes to its changes.
    /// `$state.counter` returns a SwiftUI `Binding`. `$state.ui.counter` returns a `UIBinding`.
    ///
    /// If the value has its own property `ui`, `$state.ui` returns this binding, not the property. Use `$state[\.ui]` to read the property.
    ///
    /// ### Example
    /// ```swift
    /// let counter = $state.ui.counter
    /// counter.wrappedValue = 1
    /// counter
    ///     .sink { print("Counter:", $0.new) }
    ///     .store(in: &cancellables)
    /// ```
    var ui: UIBinding<Value> {
        return observe()
    }

    /// Dynamically calls the state to return a binding to the entire value.
    ///
    /// This method enables callable syntax for accessing the full binding.
    ///
    /// - Parameter withArguments: Unused arguments array.
    /// - Returns: A `UIBinding` for the entire value.
    ///
    /// ### Example
    /// ```swift
    /// struct User: Equatable { var name: String; var age: Int }
    /// @UIState var user = User(name: "Alice", age: 30)
    ///
    /// // Get binding to entire user object
    /// let userBinding = $user()
    /// userBinding.wrappedValue.name = "Bob"
    ///
    /// // Observe changes to entire user
    /// $user().sink { user in
    ///     print("User updated: \(user.name), \(user.age)")
    /// }.store(in: &cancellables)
    /// ```
    func dynamicallyCall(withArguments: [Any]) -> UIBinding<Value> {
        return observe()
    }

    /// Dynamically calls the state with a key path to return a nested binding.
    ///
    /// This method enables callable syntax for accessing nested property bindings.
    ///
    /// - Parameter args: An array containing a single writable key path.
    /// - Returns: A `UIBinding` for the nested property.
    ///
    /// ### Example
    /// ```swift
    /// struct User: Equatable { var name: String; var age: Int }
    /// @UIState var user = User(name: "Alice", age: 30)
    ///
    /// // Get binding to specific property
    /// let nameBinding = $user(\.name)
    /// nameBinding.wrappedValue = "Bob"
    ///
    /// // Observe changes to specific property
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

public extension UIState where Value: ExpressibleByNilLiteral {
    /// Initializes the state with a `nil` value.
    convenience init() {
        self.init(wrappedValue: nil)
    }
}

public extension UIState where Value: ExpressibleByArrayLiteral {
    /// Initializes the state with an empty array.
    convenience init() {
        self.init(wrappedValue: [])
    }
}

public extension UIState where Value: ExpressibleByDictionaryLiteral {
    /// Initializes the state with an empty dictionary.
    convenience init() {
        self.init(wrappedValue: [:])
    }
}

extension UIState: Equatable where Value: Equatable {
    public static func ==(lhs: UIState<Value>, rhs: UIState<Value>) -> Bool {
        return lhs.wrappedValue == rhs.wrappedValue
    }
}

extension UIState: Hashable where Value: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(wrappedValue)
    }
}

extension UIState: CustomStringConvertible where Value: CustomStringConvertible {
    /// A textual representation of the wrapped value.
    ///
    /// This property forwards the description from the wrapped value,
    /// providing a string representation suitable for display purposes.
    ///
    /// - Returns: A string representation of the wrapped value.
    public var description: String {
        return wrappedValue.description
    }
}

extension UIState: CustomDebugStringConvertible where Value: CustomDebugStringConvertible {
    /// A textual representation of the wrapped value, suitable for debugging.
    ///
    /// This property forwards the debug description from the wrapped value,
    /// providing detailed information useful for debugging purposes.
    ///
    /// - Returns: A debug string representation of the wrapped value.
    public var debugDescription: String {
        return wrappedValue.debugDescription
    }
}

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
extension UIState: CustomLocalizedStringResourceConvertible where Value: CustomLocalizedStringResourceConvertible {
    /// A localized string resource representation of the wrapped value.
    ///
    /// This property forwards the localized string resource from the wrapped value,
    /// enabling localization support for the UI state.
    ///
    /// - Returns: A localized string resource representation of the wrapped value.
    public var localizedStringResource: LocalizedStringResource {
        return wrappedValue.localizedStringResource
    }
}

@available(iOS 13.0, macOS 10.15, *)
extension UIState: ObservableObject {
    /// A publisher that emits before each change of the value.
    ///
    /// The publisher emits one time for each change. A subscriber that reads the state in the handler gets the old value.
    /// The publisher does not emit when a subscriber subscribes, and it does not emit for an equal value.
    ///
    /// ### Example
    /// ```swift
    /// @UIState var user = User(name: "Alice", age: 30)
    ///
    /// // SwiftUI will automatically update when user changes
    /// struct ContentView: View {
    ///     @StateObject var viewModel = ViewModel()
    ///
    ///     var body: some View {
    ///         VStack {
    ///             Text("Name: \(viewModel.user.name)")
    ///             Text("Age: \(viewModel.user.age)")
    ///             Button("Update Age") {
    ///                 viewModel.user.age += 1
    ///             }
    ///         }
    ///     }
    /// }
    /// ```
    public var objectWillChange: AnyPublisher<Void, Never> {
        return objectWillChangeSubject.eraseToAnyPublisher()
    }
}

extension UIState: @unchecked Sendable {}
