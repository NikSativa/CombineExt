import Combine
import Foundation

/// A property wrapper and Combine publisher that manages reactive application state.
///
/// Use `UIState` to hold and publish value changes of any `Equatable` type.
/// It enables binding, dynamic member lookup, and diff-based state observation.
///
/// ### Example
/// ```swift
/// struct State {
///     var counter: Int
/// }
///
/// @UIState var state = State(counter: 0)
///
/// $state.counter.sink { value in
///     print("Counter changed to \(value)")
/// }.store(in: &cancellables)
///
/// state.counter = 1
/// ```
@dynamicMemberLookup
@dynamicCallable
@propertyWrapper
public final class UIState<Value: Equatable> {
    /// Internal subject that emits a `DiffedValue` each time the value is updated.
    ///
    /// This drives the `publisher` and emits a `DiffedValue<Value>` each time the `wrappedValue` is updated.
    private lazy var subject: CurrentValueSubject<DiffedValue<Value>, Failure> = CurrentValueSubject(.init(old: nil, binding: observe()))

    /// Initializes a `UIState` with a given initial value.
    ///
    /// - Parameter wrappedValue: The initial value of the state.
    public required init(wrappedValue: Value) {
        self.wrappedValue = wrappedValue
    }

    /// The current value of the state.
    ///
    /// When the value changes and differs from the previous value, a `DiffedValue` is emitted.
    public var wrappedValue: Value {
        didSet {
            if wrappedValue == oldValue {
                return
            }

            let change: DiffedValue<Value> = .init(old: oldValue, binding: observe())
            subject.send(change)
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
    public lazy var publisher: AnyPublisher<DiffedValue<Value>, Failure> = {
        return subject
            .removeDuplicates()
            .eraseToAnyPublisher()
    }()
}

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
    /// Returns a binding to a nested writable property of the state.
    ///
    /// Enables composition and binding to sub-properties using dot syntax.
    ///
    /// ### Example
    /// ```swift
    /// $state.user.name.wrappedValue = "Alice"
    /// ```
    subscript<V>(dynamicMember keyPath: WritableKeyPath<Value, V>) -> UIBinding<V> {
        return observe(keyPath)
    }

    /// Gets or sets the value of a nested writable property of the state.
    ///
    /// Allows for dot-syntax access to nested properties.
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

    /// Dynamically calls the state to return a binding to the entire value.
    ///
    /// This method enables callable syntax for accessing the full binding.
    ///
    /// - Parameter withArguments: Unused arguments array.
    /// - Returns: A `UIBinding` for the entire value.
    ///
    /// ### Example
    /// ```swift
    /// @UIState var user = User(name: "Alice", age: 30)
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

    /// Dynamically calls the state with a key path to return a nested binding.
    ///
    /// This method enables callable syntax for accessing nested property bindings.
    ///
    /// - Parameter args: An array containing a single writable key path.
    /// - Returns: A `UIBinding` for the nested property.
    ///
    /// ### Example
    /// ```swift
    /// @UIState var user = User(name: "Alice", age: 30)
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
    public var description: String {
        return wrappedValue.description
    }
}

extension UIState: CustomDebugStringConvertible where Value: CustomDebugStringConvertible {
    public var debugDescription: String {
        return wrappedValue.debugDescription
    }
}

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
extension UIState: CustomLocalizedStringResourceConvertible where Value: CustomLocalizedStringResourceConvertible {
    public var localizedStringResource: LocalizedStringResource {
        return wrappedValue.localizedStringResource
    }
}

#if swift(>=6.0)
extension UIState: @unchecked Sendable {}
#endif
