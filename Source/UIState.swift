import Combine
import Foundation

/// A property wrapper and Combine publisher that holds observable application state.
///
/// `UIState` wraps a value of any `Equatable` type and emits updates when the value changes.
/// It supports two-way binding using dynamic member lookup and provides derived bindings
/// via the `observe(_:)` method for sub-properties of the state.
///
/// Use this wrapper to manage state reactively in Combine-based architectures.
/// 
/// ### Example
/// ```swift
/// struct State {
///     var name: String
/// }
///
/// @UIState
/// var state: State = .init(name: "name")
///
/// let view = MyView()
/// view.configure(withName: $state.name)
///
/// final class MyView: UIView {
///     @UIBinding private var name: String
///     private var cancellables: Set<AnyCancellable> = []
///
///     func configure(withName name: UIBinding<String>) {
///         _name = name
///         $name
///             .sink { ... do something ... }
///             .store(in: &cancellables)
///     }
///
///     func buttonTapped() {
///         name = "new name"
///     }
/// }
/// ```
@dynamicMemberLookup
@propertyWrapper
public final class UIState<Output: Equatable>: Combine.Publisher {
    public typealias Failure = Never

    private lazy var subject: CurrentValueSubject<Output, Failure> = CurrentValueSubject(wrappedValue)
    private var observers: Set<AnyCancellable> = []

    private var underlyingValue: Output
    /// Initializes a `UIState` with a given initial value.
    /// - Parameter wrappedValue: The initial value of the state.
    public required init(wrappedValue: Output) {
        self.underlyingValue = wrappedValue
    }

    /// The current wrapped value of the state.
    /// Setting this value triggers an update to all subscribers if the value changes.
    public var wrappedValue: Output {
        get {
            return underlyingValue
        }
        set {
            if underlyingValue == newValue {
                return
            }

            underlyingValue = newValue
            subject.send(newValue)
        }
    }

    /// The projected value of the property wrapper, which is the `UIState` instance itself.
    public var projectedValue: UIState<Output> {
        return self
    }

    /// A publisher that emits the current value and all subsequent changes, removing duplicates.
    public lazy var publisher: AnyPublisher<Output, Failure> = {
        return subject
            .removeDuplicates()
            .eraseToAnyPublisher()
    }()

    /// Attaches the specified subscriber to the publisher.
    /// - Parameter subscriber: The subscriber to attach.
    public func receive<S>(subscriber: S)
    where S: Subscriber, Failure == S.Failure, Output == S.Input {
        subject.receive(subscriber: subscriber)
    }

    /// Returns a binding to a sub-property of the state specified by a key path.
    /// - Parameter keyPath: A key path to a writable property within the state.
    /// - Returns: A `UIBinding` for the specified property.
    public func observe<New>(_ keyPath: WritableKeyPath<Output, New>) -> UIBinding<New> {
        return .init(publisher: publisher.map(keyPath).eraseToAnyPublisher()) { [self] in
            return self.wrappedValue[keyPath: keyPath]
        } set: { [self] new in
            self.wrappedValue[keyPath: keyPath] = new
        }
    }
}

public extension UIState {
    /// Provides dynamic member lookup for nested writable properties.
    ///
    /// Enables dot-syntax access to nested bindings, e.g. `binding.someProperty.anotherProperty`.
    subscript<V>(dynamicMember keyPath: WritableKeyPath<Output, V>) -> UIBinding<V> {
        return observe(keyPath)
    }

    /// Provides dynamic member lookup for nested writable properties.
    ///
    /// Enables dot-syntax access to nested bindings, e.g. `binding.someProperty.anotherProperty`.
    subscript<V>(dynamicMember keyPath: WritableKeyPath<Output, V>) -> V {
        get {
            wrappedValue[keyPath: keyPath]
        }
        set {
            wrappedValue[keyPath: keyPath] = newValue
        }
    }
}

public extension UIState where Output: MutableCollection {
    /// Returns a binding to an element in a mutable collection if the index is valid.
    /// - Parameter index: The index to bind to.
    /// - Returns: A `UIBinding` for the element at the index if valid. Triggers a runtime crash if the index is invalid.
    ///
    /// ### Example
    /// ```swift
    ///    @UIState
    ///    var items: [String] = ["A", "B"]
    ///    let maybeSecond = $items.unsafe(1)  // Binds to "B"
    ///    print(maybeSecond.wrappedValue) // "B"
    ///
    ///    let maybeThird = $items.unsafe(2)   // Index 2 is out of bounds
    ///    print(maybeThird.wrappedValue) // crash: index 2 is out of bounds
    /// ```
    func unsafe(_ index: Output.Index) -> UIBinding<Output.Element> {
        let publisher: AnyPublisher<Output.Element, Failure> = publisher
            .filter { collection in
                return collection.contains(index: index)
            }
            .map { collection in
                return collection[index]
            }
            .eraseToAnyPublisher()

        return .init(publisher: publisher) { [self] in
            let collection = wrappedValue
            if collection.contains(index: index) {
                return collection[index]
            }
            fatalError("should never happen!")
        } set: { [self] newValue in
            var collection = wrappedValue
            if collection.contains(index: index) {
                collection[index] = newValue
                wrappedValue = collection
            } else {
                fatalError("should never happen!")
            }
        }
    }

    /// Returns a binding to an element in a mutable collection, returning `nil` for out-of-bounds access.
    /// - Parameter index: The index to bind to.
    /// - Returns: A `UIBinding` for the element at the index or `nil` if out of bounds.
    ///
    /// ### Example
    /// ```swift
    ///    @UIState
    ///    var items: [String?] = ["A", "B"]
    ///    let maybeSecond = $items.safe(1) // Binds to "B"
    ///    print(maybeSecond.wrappedValue ?? "None") // "B"
    ///
    ///    let maybeThird = $items.safe(2) // Index 2 is out of bounds
    ///    print(maybeThird.wrappedValue ?? "None") // "None"
    /// ```
    func safe(_ index: Output.Index) -> UIBinding<Output.Element>
    where Output.Element: ExpressibleByNilLiteral {
        return safe(index, default: nil)
    }

    /// Returns a binding to an element in a mutable collection, with a default value fallback for out-of-bounds access.
    /// - Parameters:
    ///   - index: The index to bind to.
    ///   - defaultValue: The value to use if the index is out of bounds.
    /// - Returns: A `UIBinding` for the element at the index or the default value.
    ///
    /// ### Example
    /// ```swift
    ///    @UIState
    ///    var items: [String] = ["A", "B"]
    ///    let third = $items.safe(2, default: "N/A")
    ///    print(third.wrappedValue) // "N/A" because index 2 is out of bounds
    ///    third.wrappedValue = "S"  // No-op because index 2 is still out of bounds
    ///    print(third.wrappedValue) // "N/A" because index 2 is still out of bounds
    /// ```
    func safe(_ index: Output.Index, default defaultValue: @autoclosure @escaping () -> Output.Element) -> UIBinding<Output.Element> {
        let elementPublisher: AnyPublisher<Output.Element, Failure> = publisher
            .map { collection in
                guard collection.contains(index: index) else {
                    return defaultValue()
                }
                return collection[index]
            }
            .eraseToAnyPublisher()

        return .init(publisher: elementPublisher) { [self] in
            let collection = wrappedValue
            return collection.contains(index: index) ? collection[index] : defaultValue()
        } set: { [self] newValue in
            var collection = wrappedValue
            if collection.contains(index: index) {
                collection[index] = newValue
                wrappedValue = collection
            }
        }
    }
}

public extension UIState where Output: ExpressibleByNilLiteral {
    /// Initializes a `UIState` with a `nil` value.
    convenience init() {
        self.init(wrappedValue: nil)
    }
}

public extension UIState where Output: ExpressibleByArrayLiteral {
    /// Initializes a `UIState` with an empty array.
    convenience init() {
        self.init(wrappedValue: [])
    }
}

public extension UIState where Output: ExpressibleByDictionaryLiteral {
    /// Initializes a `UIState` with an empty dictionary.
    convenience init() {
        self.init(wrappedValue: [:])
    }
}
