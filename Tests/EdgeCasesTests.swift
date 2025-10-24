import CombineExt
import Foundation
import XCTest

final class EdgeCasesTests: XCTestCase {
    func testMemoryLeaksWithValueSubject() {
        weak var weakValueSubject: ValueSubject<String>?

        do {
            let valueSubject = ValueSubject(wrappedValue: "Hello")
            weakValueSubject = valueSubject

            var cancellables = Set<AnyCancellable>()
            valueSubject.sink { _ in }.store(in: &cancellables)
        }

        // ValueSubject should be deallocated
        XCTAssertNil(weakValueSubject)
    }

    func testMemoryLeaksWithManagedState() {
        struct TestModel: BehavioralStateContract {
            var value: String = ""

            mutating func applyRules() {}

            @SubscriptionBuilder
            static func applyBindingRules(to state: RulesPublisher) -> [AnyCancellable] { [] }

            @AnyTokenBuilder<Any>
            static func applyAnyRules(to state: UIBinding<Self>) -> [Any] { [] }
        }
    }

    // MARK: - Performance Tests

    func testUIStatePerformance() {
        let uiState = UIState(wrappedValue: 0)

        measure {
            for i in 0..<1000 {
                uiState.wrappedValue = i
            }
        }
    }

    func testValueSubjectPerformance() {
        let valueSubject = ValueSubject(wrappedValue: 0)

        measure {
            for i in 0..<1000 {
                valueSubject.wrappedValue = i
            }
        }
    }

    // MARK: - Edge Cases with Nil Values

    func testUIStateWithOptionalValues() {
        let uiState = UIState(wrappedValue: String?.none)

        XCTAssertNil(uiState.wrappedValue)

        uiState.wrappedValue = "Hello"
        XCTAssertEqual(uiState.wrappedValue, "Hello")

        uiState.wrappedValue = nil
        XCTAssertNil(uiState.wrappedValue)
    }

    func testValueSubjectWithOptionalValues() {
        let valueSubject = ValueSubject(wrappedValue: String?.none)

        XCTAssertNil(valueSubject.wrappedValue)

        valueSubject.wrappedValue = "Hello"
        XCTAssertEqual(valueSubject.wrappedValue, "Hello")

        valueSubject.wrappedValue = nil
        XCTAssertNil(valueSubject.wrappedValue)
    }

    // MARK: - Edge Cases with Empty Collections

    func testUIStateWithEmptyArray() {
        let uiState = UIState(wrappedValue: [String]())

        XCTAssertTrue(uiState.wrappedValue.isEmpty)

        uiState.wrappedValue.append("Hello")
        XCTAssertEqual(uiState.wrappedValue.count, 1)
    }

    func testUIStateWithEmptyDictionary() {
        let uiState = UIState(wrappedValue: [String: String]())

        XCTAssertTrue(uiState.wrappedValue.isEmpty)

        uiState.wrappedValue["key"] = "value"
        XCTAssertEqual(uiState.wrappedValue.count, 1)
    }

    // MARK: - Edge Cases with Large Values

    func testUIStateWithLargeString() {
        let largeString = String(repeating: "A", count: 10000)
        let uiState = UIState(wrappedValue: largeString)

        XCTAssertEqual(uiState.wrappedValue.count, 10000)
        XCTAssertEqual(uiState.wrappedValue, largeString)
    }

    func testUIStateWithLargeArray() {
        let largeArray = Array(0..<10000)
        let uiState = UIState(wrappedValue: largeArray)

        XCTAssertEqual(uiState.wrappedValue.count, 10000)
        XCTAssertEqual(uiState.wrappedValue.first, 0)
        XCTAssertEqual(uiState.wrappedValue.last, 9999)
    }

    // MARK: - Edge Cases with Custom Types

    func testUIStateWithCustomEquatable() {
        struct CustomType: Equatable {
            let id: UUID
            let name: String

            init(name: String) {
                self.id = UUID()
                self.name = name
            }
        }

        let uiState = UIState(wrappedValue: CustomType(name: "Hello"))

        XCTAssertEqual(uiState.wrappedValue.name, "Hello")

        let newValue = CustomType(name: "World")
        uiState.wrappedValue = newValue
        XCTAssertEqual(uiState.wrappedValue.name, "World")
    }

    func testValueSubjectWithCustomEquatable() {
        struct CustomType: Equatable {
            let id: UUID
            let name: String

            init(name: String) {
                self.id = UUID()
                self.name = name
            }
        }

        let valueSubject = ValueSubject(wrappedValue: CustomType(name: "Hello"))

        XCTAssertEqual(valueSubject.wrappedValue.name, "Hello")

        let newValue = CustomType(name: "World")
        valueSubject.wrappedValue = newValue
        XCTAssertEqual(valueSubject.wrappedValue.name, "World")
    }

    // MARK: - Edge Cases with Circular References

    func testCircularReferenceHandling() {
        class Node: Equatable {
            var value: String
            var next: Node?

            init(value: String) {
                self.value = value
            }

            static func ==(lhs: Node, rhs: Node) -> Bool {
                return lhs.value == rhs.value
            }
        }

        let node1 = Node(value: "A")
        let node2 = Node(value: "B")
        node1.next = node2
        node2.next = node1 // Circular reference

        let uiState = UIState(wrappedValue: node1)

        XCTAssertEqual(uiState.wrappedValue.value, "A")
        XCTAssertEqual(uiState.wrappedValue.next?.value, "B")
        XCTAssertEqual(uiState.wrappedValue.next?.next?.value, "A") // Circular
    }

    // MARK: - Edge Cases with Rapid Changes

    func testRapidChanges() {
        let uiState = UIState(wrappedValue: 0)
        var receivedValues: [Int] = []

        let cancellable = uiState.publisher.sink { value in
            receivedValues.append(value)
        }

        // Rapid changes
        for i in 1...100 {
            uiState.wrappedValue = i
        }

        // Should receive all values
        XCTAssertEqual(receivedValues.count, 101) // 0 + 1...100
        XCTAssertEqual(receivedValues.last, 100)

        cancellable.cancel()
    }

    // MARK: - Additional Edge Cases

    func testUIStateWithNilValues() {
        let uiState = UIState(wrappedValue: String?.none)

        XCTAssertNil(uiState.wrappedValue)

        uiState.wrappedValue = "Hello"
        XCTAssertEqual(uiState.wrappedValue, "Hello")

        uiState.wrappedValue = nil
        XCTAssertNil(uiState.wrappedValue)
    }

    func testValueSubjectWithNilValues() {
        let valueSubject = ValueSubject(wrappedValue: String?.none)

        XCTAssertNil(valueSubject.wrappedValue)

        valueSubject.wrappedValue = "Hello"
        XCTAssertEqual(valueSubject.wrappedValue, "Hello")

        valueSubject.wrappedValue = nil
        XCTAssertNil(valueSubject.wrappedValue)
    }

    func testUIStateWithEmptyString() {
        let uiState = UIState(wrappedValue: "")

        XCTAssertTrue(uiState.wrappedValue.isEmpty)

        uiState.wrappedValue = "Hello"
        XCTAssertEqual(uiState.wrappedValue, "Hello")

        uiState.wrappedValue = ""
        XCTAssertTrue(uiState.wrappedValue.isEmpty)
    }

    func testValueSubjectWithEmptyString() {
        let valueSubject = ValueSubject(wrappedValue: "")

        XCTAssertTrue(valueSubject.wrappedValue.isEmpty)

        valueSubject.wrappedValue = "Hello"
        XCTAssertEqual(valueSubject.wrappedValue, "Hello")

        valueSubject.wrappedValue = ""
        XCTAssertTrue(valueSubject.wrappedValue.isEmpty)
    }

    func testUIStateWithZeroValues() {
        let uiState = UIState(wrappedValue: 0)

        XCTAssertEqual(uiState.wrappedValue, 0)

        uiState.wrappedValue = 42
        XCTAssertEqual(uiState.wrappedValue, 42)

        uiState.wrappedValue = 0
        XCTAssertEqual(uiState.wrappedValue, 0)
    }

    func testValueSubjectWithZeroValues() {
        let valueSubject = ValueSubject(wrappedValue: 0)

        XCTAssertEqual(valueSubject.wrappedValue, 0)

        valueSubject.wrappedValue = 42
        XCTAssertEqual(valueSubject.wrappedValue, 42)

        valueSubject.wrappedValue = 0
        XCTAssertEqual(valueSubject.wrappedValue, 0)
    }

    func testUIStateWithNegativeValues() {
        let uiState = UIState(wrappedValue: -1)

        XCTAssertEqual(uiState.wrappedValue, -1)

        uiState.wrappedValue = -100
        XCTAssertEqual(uiState.wrappedValue, -100)

        uiState.wrappedValue = 0
        XCTAssertEqual(uiState.wrappedValue, 0)
    }

    func testValueSubjectWithNegativeValues() {
        let valueSubject = ValueSubject(wrappedValue: -1)

        XCTAssertEqual(valueSubject.wrappedValue, -1)

        valueSubject.wrappedValue = -100
        XCTAssertEqual(valueSubject.wrappedValue, -100)

        valueSubject.wrappedValue = 0
        XCTAssertEqual(valueSubject.wrappedValue, 0)
    }

    func testUIStateWithBooleanValues() {
        let uiState = UIState(wrappedValue: false)

        XCTAssertFalse(uiState.wrappedValue)

        uiState.wrappedValue = true
        XCTAssertTrue(uiState.wrappedValue)

        uiState.wrappedValue = false
        XCTAssertFalse(uiState.wrappedValue)
    }

    func testValueSubjectWithBooleanValues() {
        let valueSubject = ValueSubject(wrappedValue: false)

        XCTAssertFalse(valueSubject.wrappedValue)

        valueSubject.wrappedValue = true
        XCTAssertTrue(valueSubject.wrappedValue)

        valueSubject.wrappedValue = false
        XCTAssertFalse(valueSubject.wrappedValue)
    }

    func testUIStateWithFloatValues() {
        let uiState = UIState(wrappedValue: 0.0)

        XCTAssertEqual(uiState.wrappedValue, 0.0, accuracy: 0.001)

        uiState.wrappedValue = 3.14159
        XCTAssertEqual(uiState.wrappedValue, 3.14159, accuracy: 0.001)

        uiState.wrappedValue = -2.71828
        XCTAssertEqual(uiState.wrappedValue, -2.71828, accuracy: 0.001)
    }

    func testValueSubjectWithFloatValues() {
        let valueSubject = ValueSubject(wrappedValue: 0.0)

        XCTAssertEqual(valueSubject.wrappedValue, 0.0, accuracy: 0.001)

        valueSubject.wrappedValue = 3.14159
        XCTAssertEqual(valueSubject.wrappedValue, 3.14159, accuracy: 0.001)

        valueSubject.wrappedValue = -2.71828
        XCTAssertEqual(valueSubject.wrappedValue, -2.71828, accuracy: 0.001)
    }

    func testUIStateWithCharacterValues() {
        let uiState = UIState(wrappedValue: Character("A"))

        XCTAssertEqual(uiState.wrappedValue, "A")

        uiState.wrappedValue = "Z"
        XCTAssertEqual(uiState.wrappedValue, "Z")

        uiState.wrappedValue = "1"
        XCTAssertEqual(uiState.wrappedValue, "1")
    }

    func testValueSubjectWithCharacterValues() {
        let valueSubject = ValueSubject(wrappedValue: Character("A"))

        XCTAssertEqual(valueSubject.wrappedValue, "A")

        valueSubject.wrappedValue = "Z"
        XCTAssertEqual(valueSubject.wrappedValue, "Z")

        valueSubject.wrappedValue = "1"
        XCTAssertEqual(valueSubject.wrappedValue, "1")
    }

    func testUIStateWithUnicodeValues() {
        let uiState = UIState(wrappedValue: "🚀")

        XCTAssertEqual(uiState.wrappedValue, "🚀")

        uiState.wrappedValue = "🌟"
        XCTAssertEqual(uiState.wrappedValue, "🌟")

        uiState.wrappedValue = "💻"
        XCTAssertEqual(uiState.wrappedValue, "💻")
    }

    func testValueSubjectWithUnicodeValues() {
        let valueSubject = ValueSubject(wrappedValue: "🚀")

        XCTAssertEqual(valueSubject.wrappedValue, "🚀")

        valueSubject.wrappedValue = "🌟"
        XCTAssertEqual(valueSubject.wrappedValue, "🌟")

        valueSubject.wrappedValue = "💻"
        XCTAssertEqual(valueSubject.wrappedValue, "💻")
    }

    func testUIStateWithComplexStruct() {
        struct ComplexStruct: Equatable {
            let id: UUID
            let name: String
            let value: Double
            let isActive: Bool
            let tags: [String]

            init(name: String, value: Double, isActive: Bool, tags: [String] = []) {
                self.id = UUID()
                self.name = name
                self.value = value
                self.isActive = isActive
                self.tags = tags
            }
        }

        let uiState = UIState(wrappedValue: ComplexStruct(name: "Test", value: 42.0, isActive: true, tags: ["tag1", "tag2"]))

        XCTAssertEqual(uiState.wrappedValue.name, "Test")
        XCTAssertEqual(uiState.wrappedValue.value, 42.0, accuracy: 0.001)
        XCTAssertTrue(uiState.wrappedValue.isActive)
        XCTAssertEqual(uiState.wrappedValue.tags, ["tag1", "tag2"])

        let newValue = ComplexStruct(name: "Updated", value: 100.0, isActive: false, tags: ["tag3"])
        uiState.wrappedValue = newValue

        XCTAssertEqual(uiState.wrappedValue.name, "Updated")
        XCTAssertEqual(uiState.wrappedValue.value, 100.0, accuracy: 0.001)
        XCTAssertFalse(uiState.wrappedValue.isActive)
        XCTAssertEqual(uiState.wrappedValue.tags, ["tag3"])
    }

    func testValueSubjectWithComplexStruct() {
        struct ComplexStruct: Equatable {
            let id: UUID
            let name: String
            let value: Double
            let isActive: Bool
            let tags: [String]

            init(name: String, value: Double, isActive: Bool, tags: [String] = []) {
                self.id = UUID()
                self.name = name
                self.value = value
                self.isActive = isActive
                self.tags = tags
            }
        }

        let valueSubject = ValueSubject(wrappedValue: ComplexStruct(name: "Test", value: 42.0, isActive: true, tags: ["tag1", "tag2"]))

        XCTAssertEqual(valueSubject.wrappedValue.name, "Test")
        XCTAssertEqual(valueSubject.wrappedValue.value, 42.0, accuracy: 0.001)
        XCTAssertTrue(valueSubject.wrappedValue.isActive)
        XCTAssertEqual(valueSubject.wrappedValue.tags, ["tag1", "tag2"])

        let newValue = ComplexStruct(name: "Updated", value: 100.0, isActive: false, tags: ["tag3"])
        valueSubject.wrappedValue = newValue

        XCTAssertEqual(valueSubject.wrappedValue.name, "Updated")
        XCTAssertEqual(valueSubject.wrappedValue.value, 100.0, accuracy: 0.001)
        XCTAssertFalse(valueSubject.wrappedValue.isActive)
        XCTAssertEqual(valueSubject.wrappedValue.tags, ["tag3"])
    }

    // MARK: - Stress Tests

    func testUIStateStressTest() {
        let uiState = UIState(wrappedValue: 0)
        var receivedValues: [Int] = []

        let cancellable = uiState.publisher.sink { value in
            receivedValues.append(value)
        }

        // Stress test with many rapid changes
        for i in 1...1000 {
            uiState.wrappedValue = i
        }

        XCTAssertEqual(receivedValues.count, 1001) // 0 + 1...1000
        XCTAssertEqual(receivedValues.last, 1000)

        cancellable.cancel()
    }

    func testValueSubjectStressTest() {
        let valueSubject = ValueSubject(wrappedValue: 0)
        var receivedValues: [Int] = []

        let cancellable = valueSubject.sink { value in
            receivedValues.append(value)
        }

        // Stress test with many rapid changes
        for i in 1...1000 {
            valueSubject.wrappedValue = i
        }

        XCTAssertEqual(receivedValues.count, 1001) // 0 + 1...1000
        XCTAssertEqual(receivedValues.last, 1000)

        cancellable.cancel()
    }

    func testUIStateWithLargeData() {
        let largeData = Data(repeating: 0, count: 10000)
        let uiState = UIState(wrappedValue: largeData)

        XCTAssertEqual(uiState.wrappedValue.count, 10000)

        let newLargeData = Data(repeating: 1, count: 20000)
        uiState.wrappedValue = newLargeData

        XCTAssertEqual(uiState.wrappedValue.count, 20000)
    }

    func testValueSubjectWithLargeData() {
        let largeData = Data(repeating: 0, count: 10000)
        let valueSubject = ValueSubject(wrappedValue: largeData)

        XCTAssertEqual(valueSubject.wrappedValue.count, 10000)

        let newLargeData = Data(repeating: 1, count: 20000)
        valueSubject.wrappedValue = newLargeData

        XCTAssertEqual(valueSubject.wrappedValue.count, 20000)
    }
}
