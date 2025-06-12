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
/// @UIState var user = Model(name: "Alice", age: 30)
/// $user.name.sink { print("Name changed: \($0)") }.store(in: &cancellables)
/// user.name = "Bob"  // Triggers sink output
/// ```
@dynamicMemberLookup
@propertyWrapper
public struct UIBinding<Value> {
    private let publisher: AnyPublisher<DiffedValue<Value>, Never>
    private let get: () -> Value
    private let set: (Value) -> Void

    /// The current value of the binding.
    ///
    /// Setting this value updates the source of truth and notifies any subscribers of the change.
    public var wrappedValue: Value {
        get { get() }
        nonmutating set {
            set(newValue)
        }
    }

    /// Returns the `UIBinding` itself for use with the projected value (`$`) syntax.
    ///
    /// Use this property to pass the binding as a reference, especially to child views or components.
    public var projectedValue: UIBinding<Value> {
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
        self.publisher = EventSubject().eraseToAnyPublisher()
    }

    /// Initializes a `UIBinding` with a Combine publisher, getter, and setter.
    ///
    /// - Parameters:
    ///   - publisher: An optional publisher for value changes.
    ///   - get: A closure to retrieve the current value.
    ///   - set: A closure to update the value.
    public init(publisher: AnyPublisher<DiffedValue<Value>, Never>? = nil,
                get: @escaping () -> Value,
                set: @escaping (Value) -> Void) {
        self.get = get
        self.set = set
        self.publisher = publisher ?? EventSubject().eraseToAnyPublisher()
    }
}

/// Conformance to `SafeBinding` for safe element access in collections.
extension UIBinding: SafeBinding {}

/// Conformance to `Publisher`, allowing this binding to emit value changes using Combine.
///
/// This makes `UIBinding` directly usable with Combine subscribers and operators.
extension UIBinding: Combine.Publisher {
    public typealias Output = DiffedValue<Value>
    public typealias Failure = Never

    /// Attaches the specified subscriber to receive value changes from this binding.
    ///
    /// - Parameter subscriber: The subscriber to register.
    public func receive<S>(subscriber: S) where S: Subscriber, Never == S.Failure, DiffedValue<Value> == S.Input {
        publisher.receive(subscriber: subscriber)
    }
}

public extension UIBinding {
    /// Returns a binding to a nested property using dynamic member lookup.
    ///
    /// Use this subscript to create a `UIBinding` from a key path to a nested writable property.
    ///
    /// - Parameter keyPath: A writable key path to a nested property.
    /// - Returns: A `UIBinding` to the nested property.
    ///
    /// ### Example
    /// ```swift
    /// let nameBinding = $userBinding.name
    /// nameBinding.wrappedValue = "Carol"
    /// ```
    subscript<V>(dynamicMember keyPath: WritableKeyPath<Value, V>) -> UIBinding<V> {
        return observe(keyPath)
    }

    /// Returns or sets the value of a nested property using dynamic member lookup.
    ///
    /// Enables dot-syntax for reading or writing nested values without returning a binding.
    ///
    /// - Parameter keyPath: A writable key path to a nested property.
    /// - Returns: The current value at the key path.
    ///
    /// ### Example
    /// ```swift
    /// let age = userBinding.age
    /// userBinding.age = age + 1
    /// ```
    subscript<V>(dynamicMember keyPath: WritableKeyPath<Value, V>) -> V {
        get {
            wrappedValue[keyPath: keyPath]
        }
        nonmutating set {
            wrappedValue[keyPath: keyPath] = newValue
        }
    }
}

/// Conformance to `Equatable` when the wrapped value is equatable.
///
/// Allows comparison of two bindings based on their current values.
extension UIBinding: Equatable where Value: Equatable {
    /// Returns whether two bindings currently hold equal values.
    ///
    /// - Parameters:
    ///   - lhs: A binding to compare.
    ///   - rhs: Another binding to compare.
    /// - Returns: `true` if both bindings hold equal wrapped values; otherwise, `false`.
    public static func ==(lhs: UIBinding<Value>, rhs: UIBinding<Value>) -> Bool {
        return lhs.wrappedValue == rhs.wrappedValue
    }
}

#if swift(>=6.0)
extension UIBinding: @unchecked Sendable {}
#endif
