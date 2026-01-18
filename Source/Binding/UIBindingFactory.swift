import Foundation

/// A factory for creating `UIBinding` configurations used with property wrapper initialization.
///
/// `UIBindingFactory` provides preset configurations for creating `UIBinding` instances,
/// particularly useful when initializing property wrappers where the binding must be
/// declared before all dependencies are available.
///
/// ### Example
/// ```swift
/// final class MyView: UIView {
///     @UIBinding private var name: String
///
///     override init(frame: CGRect) {
///         super.init(frame: frame)
///         _name = UIBindingFactory<String>.lazy
///     }
///
///     func configure(withName binding: UIBinding<String>) {
///         _name = binding
///     }
/// }
/// ```
public struct UIBindingFactory<Value> {
    /// A closure that creates a `UIBinding` instance when called.
    private var creator: () -> UIBinding<Value>

    /// Creates a factory with a custom binding creator closure.
    ///
    /// - Parameter creator: A closure that returns a `UIBinding<Value>` when invoked.
    public init(creator: @escaping () -> UIBinding<Value>) {
        self.creator = creator
    }

    /// Creates a factory that produces a constant binding with the specified value.
    ///
    /// The resulting binding always returns the same value and ignores all set operations.
    ///
    /// - Parameter value: The constant value that the binding will always return.
    /// - Returns: A factory that creates a constant `UIBinding`.
    ///
    /// ### Example
    /// ```swift
    /// @UIBinding private var title: String = UIBindingFactory<String>.constant("Fixed")
    /// ```
    public static func constant(_ value: Value) -> Self {
        return .init {
            return .constant(value)
        }
    }

    /// Creates a factory that produces an uninitialized binding (alias for `lazy`).
    ///
    /// The resulting binding will crash with a descriptive error if accessed before
    /// being properly initialized. This is useful for property wrappers where the
    /// binding must be declared before all dependencies are available.
    ///
    /// - Returns: A factory that creates an uninitialized `UIBinding`.
    ///
    /// ### Example
    /// ```swift
    /// @UIBinding private var name: String = UIBindingFactory<String>.uninitialized
    /// ```
    public static var uninitialized: Self {
        return lazy
    }

    /// Creates a factory that produces a lazy (uninitialized) binding.
    ///
    /// The resulting binding will crash with a descriptive error if accessed before
    /// being properly initialized. This is useful for property wrappers where the
    /// binding must be declared before all dependencies are available.
    ///
    /// - Returns: A factory that creates an uninitialized `UIBinding`.
    ///
    /// ### Example
    /// ```swift
    /// @UIBinding private var name: String = UIBindingFactory<String>.lazy
    /// ```
    public static var lazy: Self {
        return .init {
            return .init(get: {
                             fatalError(
                                 """
                                 UIBinding accessed before initialization.
                                 This binding was created with UIBindingConfigurations.lazy() and must be
                                 initialized by assigning a proper binding before use.
                                 Example: _binding = $state.property
                                 """
                             )
                         },
                         set: { _ in
                             fatalError(
                                 """
                                 UIBinding accessed before initialization.
                                 This binding was created with UIBindingConfigurations.lazy() and must be
                                 initialized by assigning a proper binding before use.
                                 Example: _binding = $state.property
                                 """
                             )
                         })
        }
    }

    /// Creates a `UIBinding` instance using the factory's creator closure.
    ///
    /// - Returns: A `UIBinding<Value>` instance created by the factory.
    public func make() -> UIBinding<Value> {
        return creator()
    }
}
