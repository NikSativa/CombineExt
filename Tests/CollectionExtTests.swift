import CombineExt
import Foundation
import XCTest

final class CollectionExtTests: XCTestCase {
    func testSafeSubscriptWithValidIndex() {
        let array = [1, 2, 3, 4, 5]

        XCTAssertEqual(array[safe: 0], 1)
        XCTAssertEqual(array[safe: 2], 3)
        XCTAssertEqual(array[safe: 4], 5)
    }

    func testSafeSubscriptWithOutOfBoundsIndex() {
        let array = [1, 2, 3, 4, 5]

        XCTAssertNil(array[safe: -1])
        XCTAssertNil(array[safe: 5])
        XCTAssertNil(array[safe: 10])
    }

    func testSafeSubscriptWithEmptyArray() {
        let array: [Int] = []

        XCTAssertNil(array[safe: 0])
        XCTAssertNil(array[safe: -1])
        XCTAssertNil(array[safe: 1])
    }

    func testSafeSubscriptWithStringArray() {
        let array = ["Hello", "World", "Swift"]

        XCTAssertEqual(array[safe: 0], "Hello")
        XCTAssertEqual(array[safe: 1], "World")
        XCTAssertEqual(array[safe: 2], "Swift")
        XCTAssertNil(array[safe: 3])
    }

    func testMutableCollectionSafeGet() {
        let array = [1, 2, 3, 4, 5]

        XCTAssertEqual(array[safe: 0], 1)
        XCTAssertEqual(array[safe: 2], 3)
        XCTAssertEqual(array[safe: 4], 5)
        XCTAssertNil(array[safe: 5])
    }

    func testMutableCollectionSafeSet() {
        var array = [1, 2, 3, 4, 5]

        // Test valid set
        array[safe: 0] = 10
        XCTAssertEqual(array[0], 10)

        array[safe: 2] = 30
        XCTAssertEqual(array[2], 30)

        // Test out of bounds set (should be ignored)
        array[safe: 10] = 100
        XCTAssertEqual(array.count, 5) // Should remain unchanged

        // Test nil set (should be ignored)
        array[safe: 1] = nil
        XCTAssertEqual(array[1], 2) // Should remain unchanged
    }

    func testMutableCollectionSafeSetWithNil() {
        var array = [1, 2, 3, 4, 5]

        // Setting nil should have no effect
        array[safe: 0] = nil
        XCTAssertEqual(array[0], 1) // Should remain unchanged

        array[safe: 2] = nil
        XCTAssertEqual(array[2], 3) // Should remain unchanged
    }

    func testMutableCollectionSafeSetWithOutOfBounds() {
        var array = [1, 2, 3, 4, 5]
        let originalCount = array.count

        // Setting out of bounds should have no effect
        array[safe: -1] = 100
        array[safe: 10] = 200
        array[safe: 100] = 300

        XCTAssertEqual(array.count, originalCount)
        XCTAssertEqual(array, [1, 2, 3, 4, 5]) // Should remain unchanged
    }

    func testMutableCollectionSafeSetWithValidValues() {
        var array = ["A", "B", "C"]

        array[safe: 0] = "X"
        array[safe: 1] = "Y"
        array[safe: 2] = "Z"

        XCTAssertEqual(array, ["X", "Y", "Z"])
    }

    func testContainsIndex() {
        let array = [1, 2, 3, 4, 5]

        // Test valid indices
        XCTAssertTrue(array.indices.contains(0))
        XCTAssertTrue(array.indices.contains(2))
        XCTAssertTrue(array.indices.contains(4))

        // Test invalid indices
        XCTAssertFalse(array.indices.contains(-1))
        XCTAssertFalse(array.indices.contains(5))
        XCTAssertFalse(array.indices.contains(10))
    }

    func testContainsIndexWithEmptyArray() {
        let array: [Int] = []

        XCTAssertFalse(array.indices.contains(0))
        XCTAssertFalse(array.indices.contains(-1))
        XCTAssertFalse(array.indices.contains(1))
    }

    func testContainsIndexWithStringArray() {
        let array = ["Hello", "World", "Swift"]

        XCTAssertTrue(array.indices.contains(0))
        XCTAssertTrue(array.indices.contains(1))
        XCTAssertTrue(array.indices.contains(2))
        XCTAssertFalse(array.indices.contains(3))
    }

    func testSafeSubscriptWithCustomCollection() {
        struct CustomCollection: Collection {
            let elements: [Int]

            var startIndex: Int { 0 }
            var endIndex: Int { elements.count }

            subscript(index: Int) -> Int {
                elements[index]
            }

            func index(after i: Int) -> Int {
                i + 1
            }
        }

        let collection = CustomCollection(elements: [10, 20, 30])

        XCTAssertEqual(collection[safe: 0], 10)
        XCTAssertEqual(collection[safe: 1], 20)
        XCTAssertEqual(collection[safe: 2], 30)
        XCTAssertNil(collection[safe: 3])
        XCTAssertNil(collection[safe: -1])
    }

    func testSafeSubscriptWithMutableCustomCollection() {
        struct CustomMutableCollection: MutableCollection {
            var elements: [Int]

            var startIndex: Int { 0 }
            var endIndex: Int { elements.count }

            subscript(index: Int) -> Int {
                get { elements[index] }
                set { elements[index] = newValue }
            }

            func index(after i: Int) -> Int {
                i + 1
            }
        }

        var collection = CustomMutableCollection(elements: [10, 20, 30])

        // Test get
        XCTAssertEqual(collection[safe: 0], 10)
        XCTAssertEqual(collection[safe: 1], 20)
        XCTAssertEqual(collection[safe: 2], 30)
        XCTAssertNil(collection[safe: 3])

        // Test set
        collection[safe: 0] = 100
        XCTAssertEqual(collection.elements[0], 100)

        collection[safe: 1] = 200
        XCTAssertEqual(collection.elements[1], 200)

        // Test out of bounds set
        collection[safe: 10] = 1000
        XCTAssertEqual(collection.elements.count, 3) // Should remain unchanged

        // Test nil set
        collection[safe: 2] = nil
        XCTAssertEqual(collection.elements[2], 30) // Should remain unchanged
    }

    func testSafeSubscriptWithArraySlice() {
        let array = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
        let slice = array[2..<7] // [3, 4, 5, 6, 7] with indices 2...6

        // ArraySlice preserves original indices
        XCTAssertEqual(slice[safe: 2], 3)
        XCTAssertEqual(slice[safe: 3], 4)
        XCTAssertEqual(slice[safe: 6], 7)
        XCTAssertNil(slice[safe: 0])
        XCTAssertNil(slice[safe: 7])
        XCTAssertNil(slice[safe: -1])
    }

    func testSafeSubscriptWithString() {
        let string = "Hello"

        XCTAssertEqual(string[safe: string.startIndex], "H")
        XCTAssertEqual(string[safe: string.index(after: string.startIndex)], "e")
        XCTAssertEqual(string[safe: string.index(string.startIndex, offsetBy: 4)], "o")
        XCTAssertNil(string[safe: string.endIndex])
        // Note: string.index(before: string.startIndex) would crash, so we don't test it
    }

    func testSafeSubscriptWithEmptyString() {
        let string = ""

        XCTAssertNil(string[safe: string.startIndex])
        XCTAssertNil(string[safe: string.endIndex])
        // Note: string.index(after: string.startIndex) would crash for empty string, so we don't test it
    }

    // MARK: - Additional CollectionExt Tests

    func testSafeSubscriptWithSingleElementArray() {
        let array = [42]

        XCTAssertEqual(array[safe: 0], 42)
        XCTAssertNil(array[safe: 1])
        XCTAssertNil(array[safe: -1])
    }

    func testMutableCollectionSafeSetWithStringArray() {
        var array = ["A", "B", "C"]

        array[safe: 0] = "X"
        array[safe: 1] = "Y"
        array[safe: 2] = "Z"

        XCTAssertEqual(array, ["X", "Y", "Z"])
    }

    func testMutableCollectionSafeSetWithOptionalValues() {
        var array: [Int?] = [1, 2, 3, 4, 5]

        array[safe: 0] = 10
        array[safe: 2] = 30
        array[safe: 4] = 50

        XCTAssertEqual(array, [10, 2, 30, 4, 50])
    }

    func testMutableCollectionSafeSetWithEmptyArray() {
        var array: [Int] = []

        array[safe: 0] = 1
        array[safe: 1] = 2

        XCTAssertEqual(array, []) // Should remain empty
    }

    func testMutableCollectionSafeSetWithSingleElement() {
        var array = [42]

        array[safe: 0] = 100
        array[safe: 1] = 200

        XCTAssertEqual(array, [100])
    }

    func testMutableCollectionSafeSetWithCustomMutableCollection() {
        struct CustomMutableCollection: MutableCollection {
            var elements: [Int]

            var startIndex: Int { elements.startIndex }
            var endIndex: Int { elements.endIndex }

            subscript(index: Int) -> Int {
                get { elements[index] }
                set { elements[index] = newValue }
            }

            func index(after i: Int) -> Int {
                return elements.index(after: i)
            }
        }

        var collection = CustomMutableCollection(elements: [1, 2, 3])

        collection[safe: 0] = 10
        collection[safe: 1] = 20
        collection[safe: 2] = 30
        collection[safe: 3] = 40 // Out of bounds

        XCTAssertEqual(collection.elements, [10, 20, 30])
    }
}
