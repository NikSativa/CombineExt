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
