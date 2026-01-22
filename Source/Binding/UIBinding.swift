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
///
/// // Subscribe to changes (receives DiffedValue)
/// $user.name.sink { diff in print("Name changed: \(diff.new)") }.store(in: &cancellables)
///
/// // Or subscribe to just new values
/// $user.name.publisher.sink { newName in print("Name changed: \(newName)") }.store(in: &cancellables)
///
/// user.name = "Bob"  // Triggers sink output
/// ```
@dynamicMemberLookup
@dynamicCallable
@propertyWrapper
public struct UIBinding<Value> {
    private let diffedPublisher: AnyPublisher<DiffedValue<Value>, Never>
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
        self.diffedPublisher = publisher ?? CurrentValueSubject(.init(old: nil, get: get, set: set)).eraseToAnyPublisher()
    }

    /// Initializes a `UIBinding` from a factory configuration.
    ///
    /// Use this initializer with `UIBindingFactory` to create bindings with preset configurations,
    /// such as constant or uninitialized bindings for property wrapper usage.
    ///
    /// - Parameter factory: A factory that creates the binding when needed.
    ///
    /// ### Example
    /// ```swift
    /// final class MyView: UIView {
    ///     @UIBinding(.placeholder) private var name: String
    ///
    ///     func configure(with name: UIBinding<String>) {
    ///         _name = name
    ///     }
    /// }
    /// ```
    public init(_ factory: UIBindingFactory<Value>) {
        self = factory.make()
    }

    /// A publisher that emits only the new values (without old values).
    ///
    /// This property provides a convenient way to subscribe to value changes
    /// when you only need the new value, not the full `DiffedValue` containing
    /// both old and new values.
    ///
    /// - Returns: A publisher emitting `Value` (not `DiffedValue<Value>`).
    ///
    /// ### Example
    /// ```swift
    /// @UIBinding private var name: String
    ///
    /// $name.publisher
    ///     .sink { newName in
    ///         print("Name changed to: \(newName)")
    ///     }
    ///     .store(in: &cancellables)
    /// ```
    ///
    /// **Note:** To receive both old and new values, subscribe directly to the binding
    /// (which conforms to `Publisher` with `Output == DiffedValue<Value>`):
    /// ```swift
    /// $name
    ///     .sink { diff in
    ///         print("Changed from \(diff.old ?? "nil") to \(diff.new)")
    ///     }
    ///     .store(in: &cancellables)
    /// ```
    public var publisher: AnyPublisher<Value, Never> {
        return justNew()
    }
}

public extension UIBinding {
    /// Creates a constant binding that cannot be modified.
    ///
    /// Use this method to create a read-only binding that always returns the same value.
    /// Any attempts to set a new value will be ignored. This is useful when you need to pass
    /// a binding to a component that requires one, but the value should remain constant.
    ///
    /// - Parameter value: The constant value that this binding will always return.
    /// - Returns: A `UIBinding` that always returns the specified value and ignores all set operations.
    ///
    /// ### Example
    /// ```swift
    /// // Create a constant binding for a fixed title
    /// let titleBinding = UIBinding<String>.constant("Fixed Title")
    ///
    /// // Reading works
    /// print(titleBinding.wrappedValue) // Prints: "Fixed Title"
    ///
    /// // Setting is ignored
    /// titleBinding.wrappedValue = "New Title"
    /// print(titleBinding.wrappedValue) // Still prints: "Fixed Title"
    ///
    /// // Useful for preview or placeholder data
    /// struct ContentView: View {
    ///     var binding: UIBinding<String>
    ///
    ///     static var previews: some View {
    ///         ContentView(binding: .constant("Preview Data"))
    ///     }
    /// }
    /// ```
    static func constant(_ value: Value) -> Self {
        return .init(get: { value },
                     set: { new in Swift.print("Attempted to set on constant binding \(new)") })
    }
}

extension UIBinding: SafeBinding {}

extension UIBinding: Combine.Publisher {
    public typealias Output = DiffedValue<Value>
    public typealias Failure = Never

    public func receive<S>(subscriber: S) where S: Subscriber, Never == S.Failure, DiffedValue<Value> == S.Input {
        diffedPublisher.receive(subscriber: subscriber)
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

    /// Dynamically calls the binding to return a binding to the entire value.
    ///
    /// This method enables callable syntax for accessing the full binding.
    ///
    /// - Parameter withArguments: Unused arguments array.
    /// - Returns: A `UIBinding` for the entire value.
    ///
    /// ### Example
    /// ```swift
    /// @UIBinding var user = User(name: "Alice", age: 30)
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

    /// Dynamically calls the binding with a key path to return a nested binding.
    ///
    /// This method enables callable syntax for accessing nested property bindings.
    ///
    /// - Parameter args: An array containing a single writable key path.
    /// - Returns: A `UIBinding` for the nested property.
    ///
    /// ### Example
    /// ```swift
    /// @UIBinding var user = User(name: "Alice", age: 30)
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
    /// A textual representation of the bound value.
    ///
    /// This property forwards the description from the bound value,
    /// providing a string representation suitable for display purposes.
    ///
    /// - Returns: A string representation of the bound value.
    public var description: String {
        return wrappedValue.description
    }
}

extension UIBinding: CustomDebugStringConvertible where Value: CustomDebugStringConvertible {
    /// A textual representation of the bound value, suitable for debugging.
    ///
    /// This property forwards the debug description from the bound value,
    /// providing detailed information useful for debugging purposes.
    ///
    /// - Returns: A debug string representation of the bound value.
    public var debugDescription: String {
        return wrappedValue.debugDescription
    }
}

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
extension UIBinding: CustomLocalizedStringResourceConvertible where Value: CustomLocalizedStringResourceConvertible {
    /// A localized string resource representation of the bound value.
    ///
    /// This property forwards the localized string resource from the bound value,
    /// enabling localization support for the UI binding.
    ///
    /// - Returns: A localized string resource representation of the bound value.
    public var localizedStringResource: LocalizedStringResource {
        return wrappedValue.localizedStringResource
    }
}

#if swift(>=6.0)
extension UIBinding: @unchecked Sendable {}
#endif
