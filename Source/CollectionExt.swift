import Foundation

/// Extension on `Collection` that adds safe element access.
public extension Collection {
    /// Safely accesses the element at the specified index.
    ///
    /// Returns `nil` if the index is out of bounds.
    ///
    /// - Parameter index: The position of the element to access.
    /// - Returns: The element at the given index if it exists; otherwise, `nil`.
    ///
    /// ### Example
    /// ```swift
    /// let array = [10, 20, 30]
    /// print(array[safe: 1]) // Optional(20)
    /// print(array[safe: 5]) // nil
    /// ```
    subscript(safe index: Index) -> Element? {
        return index >= startIndex && index < endIndex ? self[index] : nil
    }
}

/// Extension on `MutableCollection` that adds safe get/set element access.
public extension MutableCollection {
    /// Safely gets or sets the element at the specified index.
    ///
    /// When reading, returns `nil` if the index is out of bounds.
    /// When writing, replaces the element at the index only if it's within bounds and the new value is non-nil.
    ///
    /// - Note: Assigning `nil` has no effect.
    ///
    /// - Parameter index: The position of the element to access or modify.
    /// - Returns: The element at the given index if it exists; otherwise, `nil`.
    ///
    /// ### Example
    /// ```swift
    /// var array = [1, 2, 3]
    /// array[safe: 1] = 20
    /// print(array) // [1, 20, 3]
    ///
    /// array[safe: 5] = 99 // out of bounds, no effect
    /// print(array) // [1, 20, 3]
    ///
    /// array[safe: 0] = nil // nil value ignored
    /// print(array) // [1, 20, 3]
    /// ```
    subscript(safe index: Index) -> Element? {
        get {
            return index >= startIndex && index < endIndex ? self[index] : nil
        }
        set {
            if let newValue, index >= startIndex, index < endIndex {
                self[index] = newValue
            }
        }
    }
}

internal extension Collection {
    /// Checks whether the given index is within bounds of the collection.
    ///
    /// This implementation always has O(1) complexity.
    func contains(index: Index) -> Bool {
        return index >= startIndex && index < endIndex
    }
}
