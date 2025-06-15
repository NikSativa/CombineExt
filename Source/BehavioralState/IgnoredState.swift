import Foundation

/// A property wrapper that ignores its value in equality and hashing comparisons.
///
/// Use `IgnoredState` to wrap values that should not influence `Equatable` or `Hashable` behavior,
/// such as transient or cached properties in UI models. The wrapper supports dynamic member access
/// and callable closures.
///
/// - Important: All instances of `IgnoredState` are considered equal unless differentiated using the optional `id`.
///
/// ### Example
/// ```swift
/// struct ViewModel: Equatable {
///     @IgnoredState var transientCache = DataCache()
/// }
/// ```
@propertyWrapper
@dynamicMemberLookup
@dynamicCallable
public struct IgnoredState<Value>: Hashable, CustomReflectable {
    /// An optional identifier associated with the ignored value.
    ///
    /// Use this identifier to differentiate `IgnoredState` instances during hashing or equality checks,
    /// especially when the wrapped value should be excluded from comparison logic.
    ///
    /// - Note: This value is used as the hash and equality key.
    ///
    /// ### Example
    /// ```swift
    /// struct ViewModel: Hashable {
    ///     @IgnoredState(id: 1) var a = Value()
    ///     @IgnoredState(id: 2) var b = Value()
    /// }
    /// ```
    public let projectedValue: Int?

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
    public init(wrappedValue: Value, id: Int? = nil) {
        self.wrappedValue = wrappedValue
        self.projectedValue = id
    }

    /// Returns `true` when comparing any two `IgnoredState` instances.
    ///
    /// This makes it suitable for values that should be ignored in equality checks.
    ///
    /// - Parameters:
    ///   - lhs: The left-hand side `IgnoredState` instance.
    ///   - rhs: The right-hand side `IgnoredState` instance.
    /// - Returns: `true` if the identifiers are equal, otherwise `false`.
    ///
    /// ### Example
    /// ```
    /// let a = IgnoredState(wrappedValue: 1)
    /// let b = IgnoredState(wrappedValue: 2)
    /// print(a == b) // true
    /// ```
    public static func ==(lhs: Self, rhs: Self) -> Bool {
        return lhs.projectedValue == rhs.projectedValue
    }

    /// Hashes the identifier used to distinguish this instance.
    ///
    /// If `projectedValue` is `nil`, no value is contributed to the hash.
    ///
    /// - Parameter hasher: The hasher to use when combining the components of this instance.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(projectedValue)
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

    /// Dynamically calls the wrapped closure with two arguments.
    ///
    /// This method enables forwarding two parameters to a wrapped closure when `Value` is a function of type `(P1, P2) -> R`.
    ///
    /// - Parameter args: An array containing exactly two arguments to be passed to the wrapped closure.
    /// - Returns: The result of invoking the wrapped closure.
    ///
    /// - Note: A runtime error is thrown if arguments are missing or of the wrong types.
    ///
    /// ### Example
    /// ```swift
    /// @IgnoredState var closure: (Int, String) -> String = { number, word in "\(number)-\(word)" }
    /// let result: String = closure(5, "times")
    /// print(result) // "5-times"
    /// ```
    func dynamicallyCall<P1, P2, R>(withArguments args: [Any]) -> R
    where Value == (P1, P2) -> R {
        guard args.count == 2,
              let p1 = args[0] as? P1,
              let p2 = args[1] as? P2 else {
            fatalError("Expected exactly 2 arguments of correct types")
        }

        return wrappedValue(p1, p2)
    }

    /// Dynamically calls the wrapped closure with three arguments.
    ///
    /// This method enables forwarding three parameters to a wrapped closure when `Value` is a function of type `(P1, P2, P3) -> R`.
    ///
    /// - Parameter args: An array containing exactly three arguments to be passed to the wrapped closure.
    /// - Returns: The result of invoking the wrapped closure.
    ///
    /// - Note: A runtime error is thrown if the arguments are missing or of incorrect types.
    ///
    /// ### Example
    /// ```swift
    /// @IgnoredState var closure: (Int, Int, Int) -> Int = { $0 + $1 + $2 }
    /// let result: Int = closure(1, 2, 3)
    /// print(result) // "6"
    /// ```
    func dynamicallyCall<P1, P2, P3, R>(withArguments args: [Any]) -> R
    where Value == (P1, P2, P3) -> R {
        guard args.count == 3,
              let p1 = args[0] as? P1,
              let p2 = args[1] as? P2,
              let p3 = args[2] as? P3 else {
            fatalError("Expected exactly 3 arguments of correct types")
        }

        return wrappedValue(p1, p2, p3)
    }

    /// CustomReflectable conformance.
    ///
    /// Provides a mirror reflecting the wrapped value.
    public var customMirror: Mirror {
        return .init(reflecting: wrappedValue)
    }
}
