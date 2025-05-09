import Foundation

public extension Collection {
    subscript(safe index: Index) -> Element? {
        return index >= startIndex && index < endIndex ? self[index] : nil
    }
}

public extension MutableCollection {
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
    /// Complexity of `self.indices.contains(index)`
    /// O(n), where n is the length of the sequence.
    /// O(1) for RandomAccessCollection (e.g. Array), otherwise O(n).
    ///
    /// this implementation is O(1) complexity
    func contains(index: Index) -> Bool {
        return index >= startIndex && index < endIndex
    }
}
