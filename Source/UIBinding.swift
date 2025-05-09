import Combine
import Foundation

/// A Combine-compatible property wrapper and publisher used to bind to mutable state.
///
/// `UIBinding` enables reactive updates to properties using Combine publishers. It supports:
/// - Nested bindings using key paths
/// - Dynamic member access (`binding.someProperty`)
/// - Safe and unsafe element access for collections
/// This is especially useful in MVVM or reactive UI architectures.
///
/// ### Example
/// ```swift
/// struct Model {
///     var name: String
///     var age: Int
/// }
///
/// let userState = UIState(wrappedValue: Model(name: "Alice", age: 30))
/// let nameBinding = userState.observe(\.name)
///
/// nameBinding.publisher.sink { print("Name changed: \($0)") }.store(in: &cancellables)
/// nameBinding.wrappedValue = "Bob"  // Triggers sink output
/// ```
@dynamicMemberLookup
@propertyWrapper
public struct UIBinding<Output>: Combine.Publisher {
    public typealias Failure = Never

    private let publisher: AnyPublisher<Output, Failure>?
    private let get: () -> Output
    private let set: (Output) -> Void

    public var wrappedValue: Output {
        get { get() }
        nonmutating set {
            set(newValue)
        }
    }

    public var projectedValue: UIBinding<Output> {
        return self
    }

    /// Default uninitialized initializer for `UIBinding`. Not intended for direct use.
    ///
    /// This form is provided only as a workaround for some UIKit patterns, such as when a binding
    /// must be declared before all dependencies are available. It will crash at runtime if accessed.
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
    public init() {
        self.get = { fatalError("init(): must supply initial value") }
        self.set = { _ in }
        self.publisher = nil
    }

    /// Initializes a `UIBinding` with a Combine publisher, getter, and setter.
    ///
    /// - Parameters:
    ///   - publisher: An optional publisher for value changes.
    ///   - get: A closure to retrieve the current value.
    ///   - set: A closure to update the value.
    public init(publisher: AnyPublisher<Output, Failure>? = nil,
                get: @escaping () -> Output,
                set: @escaping (Output) -> Void) {
        self.get = get
        self.set = set
        self.publisher = publisher
    }

    public func receive<S>(subscriber: S)
    where S: Subscriber, Failure == S.Failure, Output == S.Input {
        publisher?.receive(subscriber: subscriber)
    }

    /// Creates a new `UIBinding` for a nested property specified by a writable key path.
    ///
    /// - Parameter keyPath: A writable key path from the current output to a nested value.
    /// - Returns: A new `UIBinding` that reacts to changes in the nested property.
    public func observe<New>(_ keyPath: WritableKeyPath<Output, New>) -> UIBinding<New> {
        let newPublisher = publisher?.map(keyPath).eraseToAnyPublisher()

        return .init(publisher: newPublisher) {
            return self.wrappedValue[keyPath: keyPath]
        } set: { [self] new in
            wrappedValue[keyPath: keyPath] = new
        }
    }
}

public extension UIBinding {
    /// Enables dynamic member access to nested writable properties, returning a projected `UIBinding`.
    ///
    /// Allows dot-syntax chaining such as `binding.address.city` where each part is bindable.
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

public extension UIBinding where Output: MutableCollection {
    /// Unsafely binds to a collection element at the given index.
    ///
    /// This will crash at runtime if the index is out of bounds. Prefer `safe(_:default:)` where possible.
    ///
    /// - Parameter index: The index of the element to access.
    /// - Returns: A `UIBinding` for the element at the given index.
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
        let publisher: AnyPublisher<Output.Element, Failure>? = publisher?
            .filter { collection in
                return collection.contains(index: index)
            }
            .map { collection in
                return collection[index]
            }
            .eraseToAnyPublisher()

        return .init(publisher: publisher) {
            let collection = wrappedValue
            if collection.contains(index: index) {
                return collection[index]
            }
            fatalError("should never happen!")
        } set: { newValue in
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

    /// Safely accesses and binds to a collection element at the given index, with a fallback value.
    ///
    /// - Parameters:
    ///   - index: The index of the element to access.
    ///   - defaultValue: A fallback value returned and published when the index is out of bounds.
    /// - Returns: A `UIBinding` for the element at the index, or the fallback value if the index is invalid.
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
        let elementPublisher: AnyPublisher<Output.Element, Failure>? = publisher?
            .map { collection in
                guard collection.contains(index: index) else {
                    return defaultValue()
                }
                return collection[index]
            }
            .eraseToAnyPublisher()

        return .init(publisher: elementPublisher) {
            let collection = wrappedValue
            return collection.contains(index: index) ? collection[index] : defaultValue()
        } set: { newValue in
            var collection = wrappedValue
            if collection.contains(index: index) {
                collection[index] = newValue
                wrappedValue = collection
            }
        }
    }
}
