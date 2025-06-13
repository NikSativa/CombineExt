import Foundation

/// A property wrapper that marks a value as equatable by always returning `true` in comparisons.
///
/// `IgnoredState` is useful when a value should not affect `Equatable` conformance, such as in diffable UI models
/// or cached data that should not trigger re-renders. This wrapper also supports `@dynamicMemberLookup`
/// allowing direct access to members of the wrapped value.
///
/// - Note: `IgnoredState` always returns `true` for equality, regardless of actual content.
///
/// ### Example
/// ```swift
/// struct ViewModel: Equatable {
///     @IgnoredState var cache = CachedData()
/// }
/// ```
@propertyWrapper
@dynamicMemberLookup
@dynamicCallable
public struct IgnoredState<Value>: Equatable {
    /// The underlying wrapped value.
    ///
    /// This is the value being stored and accessed through the property wrapper.
    ///
    /// ### Example
    /// ```
    /// struct Model {
    ///     @IgnoredState var state = State()
    /// }
    ///
    /// var model = Model()
    /// model.state = State(updated: true)
    /// ```
    public var wrappedValue: Value
    
    /// Creates a new `IgnoredState` with the given initial value.
    ///
    /// - Parameter wrappedValue: The value to store and access via the wrapper.
    ///
    /// ### Example
    /// ```
    /// let ignored = IgnoredState(wrappedValue: "internal cache")
    /// print(ignored.wrappedValue)
    /// ```
    public init(wrappedValue: Value) {
        self.wrappedValue = wrappedValue
    }
    
    /// Returns `true` when comparing any two `IgnoredState` instances.
    ///
    /// This makes it suitable for values that should be ignored in equality checks.
    ///
    /// ### Example
    /// ```
    /// let a = IgnoredState(wrappedValue: 1)
    /// let b = IgnoredState(wrappedValue: 2)
    /// print(a == b) // true
    /// ```
    public static func ==(lhs: Self, rhs: Self) -> Bool {
        return true
    }
    
    /// Provides dynamic member access to the wrapped value.
    ///
    /// Allows direct get/set of properties on the underlying value using dot syntax.
    ///
    /// - Parameter keyPath: A writable key path to a property of the wrapped value.
    /// - Returns: The value at the specified key path.
    ///
    /// ### Example
    /// ```
    /// struct Model {
    ///     var count: Int
    /// }
    ///
    /// @IgnoredState var model = Model(count: 0)
    /// model.count += 1
    /// ```
    public subscript<V>(dynamicMember keyPath: WritableKeyPath<Value, V>) -> V {
        get {
            wrappedValue[keyPath: keyPath]
        }
        set {
            wrappedValue[keyPath: keyPath] = newValue
        }
    }
    
    /// Dynamically calls the wrapped closure using the provided argument.
    ///
    /// This method enables `IgnoredState` to forward a single argument to a wrapped closure when `Value` is a function of type `(P) -> R`.
    ///
    /// - Parameter args: An array containing a single argument to be passed to the wrapped closure.
    /// - Returns: The result of invoking the wrapped closure.
    ///
    /// - Note: If no argument is provided, this method triggers a runtime crash.
    ///
    /// ### Example
    /// ```swift
    /// @IgnoredState var closure: (Int) -> String = { "\($0)" }
    /// let result: String = closure(42)
    /// print(result) // "42"
    /// ```
    func dynamicallyCall<P, R>(withArguments args: [P]) -> R
    where Value == (P) -> R {
        guard let p = args.first else {
            fatalError("No arguments")
        }
        
        return wrappedValue(p)
    }
    
    /// Dynamically calls the wrapped closure when it takes no arguments and returns a value.
    ///
    /// This overload supports closures of type `() -> R`, allowing direct call syntax on the wrapped closure.
    ///
    /// - Returns: The result of invoking the wrapped closure.
    ///
    /// ### Example
    /// ```swift
    /// @IgnoredState var closure: () -> String = { "Hello" }
    /// print(closure()) // "Hello"
    /// ```
    func dynamicallyCall<R>() -> R where Value == () -> R {
        return wrappedValue()
    }
}
