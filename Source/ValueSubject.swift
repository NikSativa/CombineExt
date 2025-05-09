import Combine
import Foundation

/// A property wrapper and publisher that holds a current value and emits new values to subscribers.
///
/// `ValueSubject` is ideal for reactive programming using Combine. It wraps a value and provides Combine-style
/// publishing and observing capabilities. It also supports property binding using key paths and dynamic member lookup.
///
/// ### Example
/// ```swift
/// struct Model {
///     var name: String
///     var age: Int
/// }
///
/// final class ViewModel {
///     @ValueSubject var user = Model(name: "Alice", age: 30)
///
///     func update() {
///         $user.name.sink { print("Name changed: \($0)") }.store(in: &cancellables)
///         user.name = "Bob" // Will trigger sink
///     }
/// }
/// ```
///
/// The `@ValueSubject` allows binding to properties such as `$user.name`, enabling reactive chains.
@dynamicMemberLookup
@propertyWrapper
public final class ValueSubject<Output>: Combine.Publisher {
    public typealias Failure = Never

    private let subject: any Subject<Output, Failure>
    private var observers: Set<AnyCancellable> = []
    private var isIgnoringNewValues: Bool = true

    private var underlyingValue: Output

    /// The current value of the subject. Setting this will publish the value to subscribers
    /// unless updates are currently being suppressed.
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

    /// Observes a specific property of the wrapped value using a writable key path,
    /// and returns a new `ValueSubject` for that property.
    ///
    /// - Parameter keyPath: The writable key path to the property to observe.
    /// - Returns: A `ValueSubject` that reflects and updates the value at the key path.
    public func observe<New>(keyPath: WritableKeyPath<Output, New>) -> ValueSubject<New> {
        let newValue = wrappedValue[keyPath: keyPath]
        let new = ValueSubject<New>(wrappedValue: newValue)

        map(keyPath)
            .dropFirst()
            .sink { [unowned new, weak self] value in
                self?.isIgnoringNewValues = false
                new.wrappedValue = value
                self?.isIgnoringNewValues = true
            }.store(in: &new.observers)

        new.dropFirst()
            .sink { [unowned self, weak new] value in
                new?.isIgnoringNewValues = false
                wrappedValue[keyPath: keyPath] = value
                new?.isIgnoringNewValues = true
            }.store(in: &observers)

        return new
    }
}

public extension ValueSubject {
    /// Provides dynamic member lookup for nested properties using key paths.
    ///
    /// This returns a `ValueSubject` bound to a sub-property of the current subject's value.
    /// It enables chaining and reactive observation of nested structures using dot-syntax.
    ///
    /// - Parameter keyPath: A writable key path from the root `Output` to a nested property.
    /// - Returns: A `ValueSubject` for the nested property.
    subscript<V>(dynamicMember keyPath: WritableKeyPath<Output, V>) -> ValueSubject<V> {
        return observe(keyPath: keyPath)
    }

    /// Directly accesses the nested property specified by the key path.
    ///
    /// This subscript enables reading and writing of a sub-property on the underlying value.
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
}

public extension ValueSubject where Output: ExpressibleByNilLiteral {
    /// Initializes a `ValueSubject` with an initial `nil` value.
    ///
    /// Available when `Output` conforms to `ExpressibleByNilLiteral`.
    convenience init() {
        self.init(wrappedValue: nil)
    }
}

public extension ValueSubject where Output: ExpressibleByArrayLiteral {
    /// Initializes a `ValueSubject` with an empty array.
    ///
    /// Available when `Output` conforms to `ExpressibleByArrayLiteral`.
    convenience init() {
        self.init(wrappedValue: [])
    }
}

public extension ValueSubject where Output: ExpressibleByDictionaryLiteral {
    /// Initializes a `ValueSubject` with an empty dictionary.
    ///
    /// Available when `Output` conforms to `ExpressibleByDictionaryLiteral`.
    convenience init() {
        self.init(wrappedValue: [:])
    }
}
