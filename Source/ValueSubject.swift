import Combine
import Foundation

/// A property wrapper and Combine publisher that stores a value and emits updates.
///
/// `ValueSubject` wraps a value and emits updates via Combine's `Publisher` protocol. It supports
/// reactive observation, dynamic member lookup, and key-path-based bindings, making it suitable for
/// building reactive architectures.
///
/// ### Example
/// ```swift
/// struct User {
///     var name: String
///     var age: Int
/// }
///
/// final class ViewModel {
///     @ValueSubject var user = User(name: "Alice", age: 30)
///
///     func observe() {
///         $user.name
///             .sink { print("Name updated:", $0) }
///             .store(in: &cancellables)
///
///         user.name = "Bob" // Triggers sink
///     }
/// }
/// ```
@dynamicMemberLookup
@propertyWrapper
public final class ValueSubject<Output>: Combine.Publisher {
    public typealias Failure = Never

    /// The internal subject that emits value changes.
    private let subject: any Subject<Output, Failure>
    /// Set of active observers for managing subscription lifecycle.
    private var observers: Set<AnyCancellable> = []
    /// Flag to prevent infinite loops during value propagation.
    private var isIgnoringNewValues: Bool = true

    /// The underlying stored value.
    private var underlyingValue: Output

    /// The current value stored in the subject.
    ///
    /// Assigning a new value emits it to subscribers, unless value propagation is suppressed internally.
    public var wrappedValue: Output {
        get {
            return underlyingValue
        }
        set {
            underlyingValue = newValue

            guard isIgnoringNewValues else {
                return
            }

            subject.send(newValue)
        }
    }

    /// Creates a new `ValueSubject` with the given initial value.
    ///
    /// - Parameter wrappedValue: The initial value to store and publish.
    public required init(wrappedValue: Output) {
        self.subject = CurrentValueSubject(wrappedValue)
        self.underlyingValue = wrappedValue
    }

    /// A publisher that emits the current and future values of the subject.
    ///
    /// Use the projected value (`$`) syntax to access the publisher.
    public lazy var projectedValue: AnyPublisher<Output, Failure> = {
        return subject.eraseToAnyPublisher()
    }()

    /// Attaches the specified subscriber to this publisher.
    ///
    /// - Parameter subscriber: The subscriber to attach to this `ValueSubject`.
    public func receive<S>(subscriber: S)
    where S: Subscriber, Failure == S.Failure, Output == S.Input {
        subject.receive(subscriber: subscriber)
    }

    /// Observes a writable key path of the wrapped value and returns a `ValueSubject` for the sub-property.
    ///
    /// This enables two-way binding between a sub-property and another subject.
    ///
    /// - Parameter keyPath: A writable key path from `Output` to the sub-value.
    /// - Returns: A `ValueSubject` bound to the nested property.
    ///
    /// ### Example
    /// ```swift
    /// let nameSubject = userSubject.observe(keyPath: \.name)
    /// nameSubject.wrappedValue = "Charlie"
    /// ```
    public func observe<New>(keyPath: WritableKeyPath<Output, New>) -> ValueSubject<New> {
        let newValue = wrappedValue[keyPath: keyPath]
        let new = ValueSubject<New>(wrappedValue: newValue)

        map(keyPath)
            .dropFirst()
            .sink { [unowned new, weak self] value in
                self?.isIgnoringNewValues = false
                new.wrappedValue = value
                self?.isIgnoringNewValues = true
            }
            .store(in: &new.observers)

        new.dropFirst()
            .sink { [unowned self, weak new] value in
                new?.isIgnoringNewValues = false
                wrappedValue[keyPath: keyPath] = value
                new?.isIgnoringNewValues = true
            }
            .store(in: &observers)

        return new
    }

    /// Creates a read-only `ValueSubject` bound to a nested property using a key path.
    ///
    /// This method creates a one-way binding that observes changes to a nested property.
    /// Unlike the writable version, this only allows reading the value, not modifying it.
    ///
    /// - Parameter keyPath: A key path to a property of the wrapped value.
    /// - Returns: A `ValueSubject` bound to the nested property.
    ///
    /// ### Example
    /// ```swift
    /// let nameSubject = userSubject.observe(keyPath: \.name)
    /// // nameSubject.wrappedValue is read-only
    /// ```
    public func observe<New>(keyPath: KeyPath<Output, New>) -> ValueSubject<New> {
        let newValue = wrappedValue[keyPath: keyPath]
        let new = ValueSubject<New>(wrappedValue: newValue)

        map(keyPath)
            .dropFirst()
            .sink { [unowned new, weak self] value in
                self?.isIgnoringNewValues = false
                new.wrappedValue = value
                self?.isIgnoringNewValues = true
            }
            .store(in: &new.observers)

        return new
    }
}

public extension ValueSubject {
    /// Returns a `ValueSubject` bound to a nested property using dynamic member lookup.
    ///
    /// Enables chaining bindings using dot-syntax, e.g. `$user.name`.
    ///
    /// - Parameter keyPath: A writable key path from the root `Output` to a nested property.
    /// - Returns: A `ValueSubject` for the nested property.
    subscript<V>(dynamicMember keyPath: WritableKeyPath<Output, V>) -> ValueSubject<V> {
        return observe(keyPath: keyPath)
    }

    /// Accesses the value of a nested property directly via dynamic member lookup.
    ///
    /// Use this to get or set nested properties directly, not as bindings.
    ///
    /// - Parameter keyPath: A writable key path to the nested property.
    /// - Returns: The current value at the given key path.
    subscript<V>(dynamicMember keyPath: WritableKeyPath<Output, V>) -> V {
        get {
            wrappedValue[keyPath: keyPath]
        }
        set {
            wrappedValue[keyPath: keyPath] = newValue
        }
    }

    /// Returns a read-only `ValueSubject` bound to a nested property using dynamic member lookup.
    ///
    /// Enables chaining bindings using dot-syntax for read-only access, e.g. `$user.name`.
    ///
    /// - Parameter keyPath: A key path from the root `Output` to a nested property.
    /// - Returns: A read-only `ValueSubject` for the nested property.
    subscript<V>(dynamicMember keyPath: KeyPath<Output, V>) -> ValueSubject<V> {
        return observe(keyPath: keyPath)
    }

    /// Accesses the value of a nested property directly via dynamic member lookup (read-only).
    ///
    /// Use this to get nested properties directly, not as bindings.
    ///
    /// - Parameter keyPath: A key path to the nested property.
    /// - Returns: The current value at the given key path.
    subscript<V>(dynamicMember keyPath: KeyPath<Output, V>) -> V {
        wrappedValue[keyPath: keyPath]
    }
}

public extension ValueSubject where Output: ExpressibleByNilLiteral {
    /// Initializes the subject with a `nil` value.
    ///
    /// Available when `Output` conforms to `ExpressibleByNilLiteral`.
    convenience init() {
        self.init(wrappedValue: nil)
    }
}

public extension ValueSubject where Output: ExpressibleByArrayLiteral {
    /// Initializes the subject with an empty array.
    ///
    /// Available when `Output` conforms to `ExpressibleByArrayLiteral`.
    convenience init() {
        self.init(wrappedValue: [])
    }
}

public extension ValueSubject where Output: ExpressibleByDictionaryLiteral {
    /// Initializes the subject with an empty dictionary.
    ///
    /// Available when `Output` conforms to `ExpressibleByDictionaryLiteral`.
    convenience init() {
        self.init(wrappedValue: [:])
    }
}

@available(iOS 13.0, macOS 10.15, *)
extension ValueSubject: ObservableObject {
    /// The objectWillChange publisher required by ObservableObject.
    ///
    /// This publisher emits before the wrapped value changes, enabling SwiftUI
    /// to update views reactively when the value is modified.
    ///
    /// ### Example
    /// ```swift
    /// @ValueSubject var counter = 0
    ///
    /// // SwiftUI will automatically update when counter changes
    /// struct ContentView: View {
    ///     @StateObject var viewModel = ViewModel()
    ///
    ///     var body: some View {
    ///         Text("Count: \(viewModel.counter)")
    ///             .onTapGesture {
    ///                 viewModel.counter += 1
    ///             }
    ///     }
    /// }
    /// ```
    public var objectWillChange: AnyPublisher<Void, Never> {
        return projectedValue
            .map { _ in () }
            .eraseToAnyPublisher()
    }
}

#if swift(>=6.0)
extension ValueSubject: @unchecked Sendable {}
#endif
