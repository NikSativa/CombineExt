import Combine
import Foundation

/// A Combine-compatible property wrapper and publisher used to bind to mutable state.
///
/// `UIBinding` enables reactive updates to properties using Combine publishers. It supports:
/// - Nested bindings using key paths
/// - Dynamic member access (`binding.someProperty`)
/// - Safe and unsafe element access for collections
/// This is especially useful in MVVM or reactive UI architectures, allowing views to reactively update when underlying data changes.
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
    ///
    /// ### Example
    /// ```swift
    /// func bind(_ binding: UIBinding<String>) {
    ///     $binding.sink { print($0) }.store(in: &cancellables)
    /// }
    /// ```
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

    /// Initializes a constant `UIBinding` with an immutable value. Not intended for direct use.
    ///
    /// This initializer is useful when you need a read-only binding that never emits changes.
    /// It can be used for previews, test data, or placeholder values where dynamic updates are not needed.
    ///
    /// - Parameter wrappedValue: The constant value to expose.
    ///
    /// ### Example
    /// ```swift
    /// let constantName: UIBinding<String> = UIBinding(wrappedValue: "Read-only")
    /// print(constantName.wrappedValue) // "Read-only"
    /// ```
    public init(wrappedValue value: Value) {
        self.get = { value }
        self.set = { _ in }
        self.publisher = EventSubject().eraseToAnyPublisher()
    }

    /// Initializes a `UIBinding` with a publisher, getter, and setter.
    ///
    /// Use this initializer when constructing bindings manually from existing sources of truth,
    /// such as external models, state containers, or dynamic data.
    ///
    /// - Parameters:
    ///   - publisher: A publisher emitting `DiffedValue<Value>`, used for downstream subscriptions.
    ///   - get: A closure that returns the current value.
    ///   - set: A closure to update the value.
    ///
    /// ### Example
    /// ```swift
    /// let state = MyModel()
    /// let binding = UIBinding(
    ///     publisher: subject.eraseToAnyPublisher(),
    ///     get: { state.title },
    ///     set: { state.title = $0 }
    /// )
    /// ```
    public init(publisher: AnyPublisher<DiffedValue<Value>, Never>? = nil,
                get: @escaping () -> Value,
                set: @escaping (Value) -> Void) {
        self.get = get
        self.set = set
        self.publisher = publisher ?? EventSubject().eraseToAnyPublisher()
    }
}

extension UIBinding: SafeBinding {}

extension UIBinding: Combine.Publisher {
    public typealias Output = DiffedValue<Value>
    public typealias Failure = Never

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

extension UIBinding: Equatable where Value: Equatable {
    public static func ==(lhs: UIBinding<Value>, rhs: UIBinding<Value>) -> Bool {
        return lhs.wrappedValue == rhs.wrappedValue
    }
}

extension UIBinding: Hashable where Value: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(wrappedValue)
    }
}

extension UIBinding: CustomStringConvertible where Value: CustomStringConvertible {
    public var description: String {
        return wrappedValue.description
    }
}

extension UIBinding: CustomDebugStringConvertible where Value: CustomDebugStringConvertible {
    public var debugDescription: String {
        return wrappedValue.debugDescription
    }
}

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
extension UIBinding: CustomLocalizedStringResourceConvertible where Value: CustomLocalizedStringResourceConvertible {
    public var localizedStringResource: LocalizedStringResource {
        return wrappedValue.localizedStringResource
    }
}

#if swift(>=6.0)
extension UIBinding: @unchecked Sendable {}
#endif
