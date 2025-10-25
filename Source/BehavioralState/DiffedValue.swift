import Foundation

/// A structure that encapsulates a value transition by storing the old and new states.
///
/// Use `DiffedValue` to observe state changes where both the previous and updated values
/// are relevant, such as during view model updates, change tracking, or reactive UI binding.
///
/// The structure supports dynamic member lookup for accessing and updating properties
/// of the new value using dot-syntax.
///
/// ### Example
/// ```swift
/// struct Counter { var count: Int }
/// var change = DiffedValue(old: Counter(count: 1), new: Counter(count: 2))
/// print("Changed from \(change.old?.count ?? 0) to \(change.count)")
/// change.count = 3
/// print(change.new.count) // 3
/// ```
@dynamicMemberLookup
public struct DiffedValue<Value> {
    /// The previous value before the transition occurred.
    ///
    /// This property may be `nil` if there was no prior state, such as during initial assignment.
    public let old: Value?
    /// The updated value after the transition.
    ///
    /// Setting this value updates the internal state and triggers any associated bindings.
    ///
    /// ### Example
    /// ```swift
    /// var diff = DiffedValue(old: "Hello", new: "World")
    /// diff.new = "Swift"
    /// print(diff.new) // "Swift"
    /// ```
    public var new: Value {
        get {
            return get()
        }
        nonmutating set {
            set(newValue)
        }
    }

    /// Erase subscription flow.
    ///
    /// This property is used internally to manage bindings to the new value.
    public let get: () -> Value
    public let set: (Value) -> Void

    /// Creates a new `DiffedValue` instance with an optional old value and a new binding.
    ///
    /// - Parameters:
    ///   - old: The previous value before the change. May be `nil` if no previous value exists.
    ///   - new: A binding to the new value.
    public init(old: Value?, get: @escaping () -> Value, set: @escaping (Value) -> Void) {
        self.old = old
        self.get = get
        self.set = set
    }

    /// Creates a new `DiffedValue` instance with an optional old value and a new binding.
    ///
    /// - Parameters:
    ///   - old: The previous value before the change. May be `nil` if no previous value exists.
    ///   - new: A binding to the new value.
    public init(old: Value?, get: @autoclosure @escaping () -> Value, set: @escaping (Value) -> Void) {
        self.old = old
        self.get = get
        self.set = set
    }

    public init(old: Value?, binding: UIBinding<Value>) {
        self.old = old
        self.get = { binding.wrappedValue }
        self.set = { binding.wrappedValue = $0 }
    }

    /// Maps the diffed value to a nested property using a writable key path.
    ///
    /// This method creates a new `DiffedValue` that tracks changes to a specific property
    /// of the wrapped value, enabling fine-grained observation of nested state changes.
    ///
    /// - Parameter keyPath: A writable key path to the nested property to observe.
    /// - Returns: A new `DiffedValue` that tracks changes to the specified property.
    ///
    /// ### Example
    /// ```swift
    /// struct User {
    ///     var name: String
    ///     var age: Int
    /// }
    ///
    /// let userDiff = DiffedValue(old: User(name: "Alice", age: 25),
    ///                           new: User(name: "Bob", age: 30))
    /// let nameDiff = userDiff.map(keyPath: \.name)
    /// print(nameDiff.old) // "Alice"
    /// print(nameDiff.new) // "Bob"
    /// ```
    public func map<V>(keyPath: WritableKeyPath<Value, V>) -> DiffedValue<V> {
        return .init(old: old?[keyPath: keyPath],
                     get: new[keyPath: keyPath],
                     set: { new[keyPath: keyPath] = $0 })
    }

    /// Checks if a specific property has changed between the old and new values.
    ///
    /// This method compares the values at the specified key path between the old and new
    /// values and returns `true` if they differ, `false` if they are equal.
    ///
    /// - Parameter keyPath: A key path to the property to compare.
    /// - Returns: `true` if the property has changed, `false` otherwise.
    ///            Returns `true` if there is no old value (initial state).
    ///
    /// ### Example
    /// ```swift
    /// struct User {
    ///     var name: String
    ///     var age: Int
    /// }
    ///
    /// let userDiff = DiffedValue(old: User(name: "Alice", age: 25),
    ///                           new: User(name: "Bob", age: 25))
    /// print(userDiff.hasChanged(keyPath: \.name)) // true
    /// print(userDiff.hasChanged(keyPath: \.age))  // false
    /// ```
    public func hasChanged(keyPath: KeyPath<Value, some Equatable>) -> Bool {
        guard let old else {
            return true
        }

        return differs(lhs: old, rhs: new, keyPath: keyPath)
    }

    /// Executes a closure when a specific property has changed between old and new values.
    ///
    /// This method provides a convenient way to perform side effects only when a particular
    /// property has actually changed, avoiding unnecessary work when values remain the same.
    ///
    /// - Parameters:
    ///   - keyPath: A key path to the property to monitor for changes.
    ///   - workItem: A closure that receives the old and new values of the property.
    ///               The old value may be `nil` if this is the initial state.
    ///
    /// ### Example
    /// ```swift
    /// struct User {
    ///     var name: String
    ///     var age: Int
    /// }
    ///
    /// let userDiff = DiffedValue(old: User(name: "Alice", age: 25),
    ///                           new: User(name: "Bob", age: 25))
    ///
    /// userDiff.ifChanged(keyPath: \.name) { oldName, newName in
    ///     print("Name changed from '\(oldName ?? "nil")' to '\(newName)'")
    /// }
    /// // Prints: "Name changed from 'Alice' to 'Bob'"
    ///
    /// userDiff.ifChanged(keyPath: \.age) { oldAge, newAge in
    ///     print("Age changed from \(oldAge ?? 0) to \(newAge)")
    /// }
    /// // Nothing printed - age didn't change
    /// ```
    public func ifChanged<V: Equatable>(keyPath: KeyPath<Value, V>, do workItem: (_ old: V?, _ new: V) -> Void) {
        if hasChanged(keyPath: keyPath) {
            workItem(old?[keyPath: keyPath], new[keyPath: keyPath])
        }
    }
}

public extension DiffedValue {
    /// Accesses nested writable properties of the `new` value using dynamic member lookup.
    ///
    /// Allows you to get and set properties of `new` directly via dot-syntax.
    ///
    /// - Parameter keyPath: A writable key path from the root value to a property.
    /// - Returns: The current value at the specified key path.
    ///
    /// ### Example
    /// ```swift
    /// struct Size { var width: Int; var height: Int }
    /// var diff = DiffedValue(old: Size(width: 100, height: 200), new: Size(width: 120, height: 240))
    /// diff.height = 250
    /// print(diff.new.height) // 250
    /// ```
    subscript<V>(dynamicMember keyPath: WritableKeyPath<Value, V>) -> V {
        get {
            new[keyPath: keyPath]
        }
        set {
            new[keyPath: keyPath] = newValue
        }
    }

    subscript<V>(dynamicMember keyPath: KeyPath<Value, V>) -> V {
        new[keyPath: keyPath]
    }
}

extension DiffedValue: CustomDebugStringConvertible {
    /// A textual representation of this diffed value, suitable for debugging.
    ///
    /// This property provides a detailed description of both the old and new values
    /// in the diffed value, making it useful for debugging and logging purposes.
    ///
    /// - Returns: A string representation showing both old and new values.
    public var debugDescription: String {
        return "DiffedValue(old: \(String(describing: old)), new: \(new))"
    }
}

extension DiffedValue: Equatable where Value: Equatable {
    public static func ==(_: Self, rhs: Self) -> Bool {
        return rhs.old == rhs.new
    }
}

extension DiffedValue: Hashable where Value: Hashable {
    /// Hashes the essential components of this diffed value.
    ///
    /// This method combines the hash values of both the old and new values
    /// to create a unique hash for the diffed value.
    ///
    /// - Parameter hasher: The hasher to use when combining the components.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(old)
        hasher.combine(new)
    }
}

#if swift(>=6.0)
extension DiffedValue: @unchecked Sendable where Value: Sendable {}
#endif
