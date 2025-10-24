import CombineExt
import Foundation
import XCTest

final class SafeBindingTests: XCTestCase {
    private var cancellables: Set<AnyCancellable> = []

    override func setUp() {
        super.setUp()
        cancellables.removeAll()
    }

    // MARK: - Basic SafeBinding Tests

    func testSafeBindingJustNew() {
        @UIState
        var counter: Int = 0

        var receivedValues: [Int] = []
        $counter.justNew().sink { receivedValues.append($0) }.store(in: &cancellables)

        counter = 1
        counter = 2

        XCTAssertEqual(receivedValues, [0, 1, 2])
    }

    func testSafeBindingJustNewWithKeyPath() {
        struct TestStruct: Equatable {
            var id: Int
            var name: String
        }

        @UIState
        var testStruct = TestStruct(id: 0, name: "initial")

        var receivedIds: [Int] = []
        var receivedNames: [String] = []

        $testStruct.justNew(\.id).sink { receivedIds.append($0) }.store(in: &cancellables)
        $testStruct.justNew(\.name).sink { receivedNames.append($0) }.store(in: &cancellables)

        testStruct = TestStruct(id: 1, name: "updated")
        testStruct = TestStruct(id: 2, name: "final")

        XCTAssertEqual(receivedIds, [0, 1, 2])
        XCTAssertEqual(receivedNames, ["initial", "updated", "final"])
    }

    func testSafeBindingExtractNew() {
        struct TestStruct: Equatable {
            var value: Int
        }

        @UIState
        var testStruct = TestStruct(value: 0)

        var receivedValues: [Int] = []
        $testStruct.extractNew(\.value).sink { receivedValues.append($0) }.store(in: &cancellables)

        testStruct = TestStruct(value: 1)
        testStruct = TestStruct(value: 2)

        XCTAssertEqual(receivedValues, [0, 1, 2])
    }

    func testSafeBindingObserve() {
        @UIState
        var counter: Int = 0

        let binding = $counter.observe()

        XCTAssertEqual(binding.wrappedValue, 0)

        binding.wrappedValue = 5
        XCTAssertEqual(counter, 5)
    }

    func testSafeBindingObserveWithKeyPath() {
        struct TestStruct: Equatable {
            var id: Int
            var name: String
        }

        @UIState
        var testStruct = TestStruct(id: 0, name: "initial")

        let idBinding = $testStruct.observe(\.id)
        let nameBinding = $testStruct.observe(\.name)

        XCTAssertEqual(idBinding.wrappedValue, 0)
        XCTAssertEqual(nameBinding.wrappedValue, "initial")

        idBinding.wrappedValue = 5
        nameBinding.wrappedValue = "updated"

        XCTAssertEqual(testStruct.id, 5)
        XCTAssertEqual(testStruct.name, "updated")
    }

    // MARK: - Collection SafeBinding Tests

    func testSafeBindingWithArray() {
        @UIState
        var items: [String] = ["A", "B", "C"]

        var receivedValues: [[String]] = []
        $items.sink { receivedValues.append($0.new) }.store(in: &cancellables)

        items = ["D", "E", "F"]
        items = ["G", "H", "I"]

        XCTAssertEqual(receivedValues, [["A", "B", "C"], ["D", "E", "F"], ["G", "H", "I"]])
    }

    func testSafeBindingArrayUnsafeAccess() {
        @UIState
        var items: [String] = ["A", "B", "C"]

        let firstItem = $items.unsafe(0)
        let secondItem = $items.unsafe(1)

        XCTAssertEqual(firstItem.wrappedValue, "A")
        XCTAssertEqual(secondItem.wrappedValue, "B")

        firstItem.wrappedValue = "X"
        secondItem.wrappedValue = "Y"

        XCTAssertEqual(items, ["X", "Y", "C"])
    }

    func testSafeBindingArraySafeAccess() {
        @UIState
        var items: [String] = ["A", "B"]

        let validItem = $items.safe(1, default: "DEFAULT")
        let invalidItem = $items.safe(5, default: "DEFAULT")

        XCTAssertEqual(validItem.wrappedValue, "B")
        XCTAssertEqual(invalidItem.wrappedValue, "DEFAULT")

        validItem.wrappedValue = "UPDATED"
        invalidItem.wrappedValue = "SHOULD_NOT_CHANGE"

        XCTAssertEqual(items, ["A", "UPDATED"])
        XCTAssertEqual(invalidItem.wrappedValue, "DEFAULT") // Should remain unchanged
    }

    func testSafeBindingArraySafeAccessWithoutDefault() {
        @UIState
        var items: [String] = ["A", "B", "C"]

        let item = $items.safe(1)

        XCTAssertEqual(item.wrappedValue, "B")

        item.wrappedValue = "UPDATED"

        XCTAssertEqual(items, ["A", "UPDATED", "C"])
    }

    func testSafeBindingBindingArray() {
        @UIState
        var items: [String] = ["A", "B", "C"]

        let bindings = $items.bindingArray()

        XCTAssertEqual(bindings.count, 3)
        XCTAssertEqual(bindings[0].wrappedValue, "A")
        XCTAssertEqual(bindings[1].wrappedValue, "B")
        XCTAssertEqual(bindings[2].wrappedValue, "C")

        bindings[0].wrappedValue = "X"
        bindings[1].wrappedValue = "Y"
        bindings[2].wrappedValue = "Z"

        XCTAssertEqual(items, ["X", "Y", "Z"])
    }

    func testSafeBindingWithEmptyArray() {
        @UIState
        var items: [String] = []

        let bindings = $items.bindingArray()
        XCTAssertEqual(bindings.count, 0)

        items = ["A", "B"]
        let newBindings = $items.bindingArray()
        XCTAssertEqual(newBindings.count, 2)
    }

    func testSafeBindingArrayObservableChanges() {
        @UIState
        var items: [String] = ["A", "B", "C"]

        let firstItem = $items.unsafe(0)
        var receivedValues: [String] = []

        firstItem.sink { receivedValues.append($0.new) }.store(in: &cancellables)

        items[0] = "X"
        items[0] = "Y"

        XCTAssertEqual(receivedValues, ["A", "X", "Y"])
    }

    func testSafeBindingWithStringArray() {
        @UIState
        var strings: [String] = ["Hello", "World"]

        let firstString = $strings.safe(0, default: "DEFAULT")
        let secondString = $strings.safe(1, default: "DEFAULT")
        let thirdString = $strings.safe(2, default: "DEFAULT")

        XCTAssertEqual(firstString.wrappedValue, "Hello")
        XCTAssertEqual(secondString.wrappedValue, "World")
        XCTAssertEqual(thirdString.wrappedValue, "DEFAULT")

        firstString.wrappedValue = "Hi"
        secondString.wrappedValue = "Universe"
        thirdString.wrappedValue = "ShouldNotChange"

        XCTAssertEqual(strings, ["Hi", "Universe"])
        XCTAssertEqual(thirdString.wrappedValue, "DEFAULT")
    }

    func testSafeBindingWithIntArray() {
        @UIState
        var numbers: [Int] = [1, 2, 3, 4, 5]

        let middleNumber = $numbers.safe(2, default: 0)
        let outOfBoundsNumber = $numbers.safe(10, default: -1)

        XCTAssertEqual(middleNumber.wrappedValue, 3)
        XCTAssertEqual(outOfBoundsNumber.wrappedValue, -1)

        middleNumber.wrappedValue = 100
        outOfBoundsNumber.wrappedValue = 200 // Should not affect array

        XCTAssertEqual(numbers, [1, 2, 100, 4, 5])
        XCTAssertEqual(outOfBoundsNumber.wrappedValue, -1)
    }

    func testSafeBindingArrayModification() {
        @UIState
        var items: [String] = ["A", "B", "C"]

        let firstItem = $items.unsafe(0)

        // Test that modifying through binding updates the array
        firstItem.wrappedValue = "MODIFIED"
        XCTAssertEqual(items[0], "MODIFIED")

        // Test that modifying the array updates the binding
        items[0] = "ARRAY_MODIFIED"
        XCTAssertEqual(firstItem.wrappedValue, "ARRAY_MODIFIED")
    }

    func testSafeBindingWithCustomCollection() {
        struct CustomCollection: MutableCollection, Equatable {
            var elements: [String] = []

            var startIndex: Int { elements.startIndex }
            var endIndex: Int { elements.endIndex }

            subscript(index: Int) -> String {
                get { elements[index] }
                set { elements[index] = newValue }
            }

            func index(after i: Int) -> Int {
                return elements.index(after: i)
            }
        }

        @UIState
        var customCollection = CustomCollection(elements: ["X", "Y", "Z"])

        let firstElement = $customCollection.safe(0, default: "DEFAULT")
        let outOfBoundsElement = $customCollection.safe(5, default: "DEFAULT")

        XCTAssertEqual(firstElement.wrappedValue, "X")
        XCTAssertEqual(outOfBoundsElement.wrappedValue, "DEFAULT")

        firstElement.wrappedValue = "MODIFIED"
        XCTAssertEqual(customCollection.elements[0], "MODIFIED")
    }

    // MARK: - Edge Cases and Error Handling

    func testSafeBindingWithNilValues() {
        @UIState
        var optionalValue: String? = nil

        var receivedValues: [String?] = []
        $optionalValue.justNew().sink { receivedValues.append($0) }.store(in: &cancellables)

        optionalValue = "Hello"
        optionalValue = nil
        optionalValue = "World"

        XCTAssertEqual(receivedValues, [nil, "Hello", nil, "World"])
    }

    func testSafeBindingWithComplexNestedStructure() {
        struct NestedStruct: Equatable {
            var id: Int
            var name: String
            var items: [String]
        }

        @UIState
        var nested = NestedStruct(id: 1, name: "Test", items: ["A", "B"])

        let idBinding = $nested.observe(\.id)
        let nameBinding = $nested.observe(\.name)
        let itemsBinding = $nested.observe(\.items)

        XCTAssertEqual(idBinding.wrappedValue, 1)
        XCTAssertEqual(nameBinding.wrappedValue, "Test")
        XCTAssertEqual(itemsBinding.wrappedValue, ["A", "B"])

        idBinding.wrappedValue = 2
        nameBinding.wrappedValue = "Updated"
        itemsBinding.wrappedValue = ["C", "D"]

        XCTAssertEqual(nested.id, 2)
        XCTAssertEqual(nested.name, "Updated")
        XCTAssertEqual(nested.items, ["C", "D"])
    }

    func testSafeBindingCustomMirror() {
        @UIState
        var value: Int = 42

        let mirror = $value.customMirror
        XCTAssertNotNil(mirror)
    }
}
