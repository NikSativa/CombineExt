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
            return bindableNew
        }
        nonmutating set {
            bindableNew = newValue
        }
    }

    /// Erase subscription flow.
    ///
    /// This property is used internally to manage bindings to the new value.
    @UIBinding
    internal var bindableNew: Value

    /// Creates a new `DiffedValue` instance with an optional old value and a new binding.
    ///
    /// - Parameters:
    ///   - old: The previous value before the change. May be `nil` if no previous value exists.
    ///   - new: A binding to the new value.
    init(old: Value?, new: UIBinding<Value>) {
        self.old = old
        self._bindableNew = new
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
}

extension DiffedValue: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "DiffedValue(old: \(String(describing: old)), new: \(new))"
    }
}

extension DiffedValue: Equatable where Value: Equatable {}

#if swift(>=6.0)
extension DiffedValue: Sendable where Value: Sendable {}
#endif
