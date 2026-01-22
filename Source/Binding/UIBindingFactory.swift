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
///     @UIBinding(.placeholder) private var name: String
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

    /// Creates a factory that produces an uninitialized binding (alias for `placeholder`).
    ///
    /// The resulting binding will crash with a descriptive error if accessed before
    /// being properly initialized. This is useful for property wrappers where the
    /// binding must be declared before all dependencies are available.
    ///
    /// - Returns: A factory that creates an uninitialized `UIBinding`.
    ///
    /// ### Example
    /// ```swift
    /// final class MyView: UIView {
    ///     @UIBinding(.uninitialized) private var name: String
    ///
    ///     func configure(with name: String) {
    ///         _name = name
    ///     }
    /// }
    public static var uninitialized: Self {
        return placeholder
    }

    /// Creates a factory that produces a placeholder (uninitialized) binding.
    ///
    /// The resulting binding will crash with a descriptive error if accessed before
    /// being properly initialized. This is useful for property wrappers where the
    /// binding must be declared before all dependencies are available.
    ///
    /// - Returns: A factory that creates an uninitialized `UIBinding`.
    ///
    /// ### Example
    /// ```swift
    /// final class MyView: UIView {
    ///     @UIBinding(.placeholder) private var name: String
    ///
    ///     func configure(with name: String) {
    ///         _name = name
    ///     }
    /// }
    /// ```
    public static var placeholder: Self {
        return .init {
            return .init(get: {
                             fatalError(
                                 """
                                 UIBinding accessed before initialization.
                                 This binding was created with UIBindingFactory.placeholder and must be
                                 initialized by assigning a proper binding before use.
                                 Example: _binding = $state.property
                                 """
                             )
                         },
                         set: { _ in
                             fatalError(
                                 """
                                 UIBinding accessed before initialization.
                                 This binding was created with UIBindingFactory.placeholder and must be
                                 initialized by assigning a proper binding before use.
                                 Example: _binding = $state.property
                                 """
                             )
                         })
        }
    }

    /// Creates a factory that produces a lazy (uninitialized) binding (deprecated: use `placeholder` instead).
    ///
    /// - Warning: This property is deprecated. Use `placeholder` instead for better clarity.
    /// - Returns: A factory that creates an uninitialized `UIBinding`.
    @available(*, deprecated, renamed: "placeholder", message: "Use 'placeholder' instead for better clarity")
    public static var lazy: Self {
        return placeholder
    }

    /// Creates a `UIBinding` instance using the factory's creator closure.
    ///
    /// - Returns: A `UIBinding<Value>` instance created by the factory.
    public func make() -> UIBinding<Value> {
        return creator()
    }
}
