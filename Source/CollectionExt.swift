import Foundation

public extension Collection {
    /// Safely access an element at the given index. Returns nil if the index is out of bounds.
    subscript(safe index: Index) -> Element? {
        return index >= startIndex && index < endIndex ? self[index] : nil
    }
}

public extension MutableCollection {
    /// Safely get or set an element at the given index. Setting does nothing if the index is out of bounds.
    ///
    /// - Note: A nil value will not alter the collection.
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
