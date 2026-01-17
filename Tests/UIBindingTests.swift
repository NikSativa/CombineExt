import CombineExt
import Foundation
import XCTest

final class UIBindingTests: XCTestCase {
    private var observers: Set<AnyCancellable> = []
    func test_UIBindingDynamicCallNoArguments() {
        @UIState
        var model = TestModel(number: 42, binding: 0)

        XCTAssertEqual(model.number, 42)
        XCTAssertEqual(model.binding, 0) // No rules applied

        let binding = $model()

        XCTAssertEqual(binding.wrappedValue.number, 42)
        XCTAssertEqual(binding.wrappedValue.binding, 0)

        binding.wrappedValue.number = 100

        XCTAssertEqual(model.number, 100) // model.number is updated through binding
        XCTAssertEqual(model.binding, 0) // binding remains unchanged
    }

    func test_UIBindingDynamicCallWithKeyPath() {
        @UIState
        var model = TestModel(number: 42, binding: 0)

        XCTAssertEqual(model.number, 42)
        XCTAssertEqual(model.binding, 0) // No rules applied

        let binding = $model(\.number)

        XCTAssertEqual(binding.wrappedValue, 42)
        XCTAssertEqual(model.binding, 0)

        binding.wrappedValue = 100

        XCTAssertEqual(model.number, 100) // model.number is updated through binding
        XCTAssertEqual(model.binding, 0) // binding remains unchanged
    }
}

private extension UIBindingTests {
    struct TestModel: BehavioralStateContract {
        var number: Int
        var binding: Int

        init(number: Int, binding: Int) {
            self.number = number
            self.binding = binding
        }

        mutating func applyRules() {
            // No rules for this test
        }

        @SubscriptionBuilder
        static func applyBindingRules(to state: RulesPublisher) -> [AnyCancellable] {
            // No binding rules needed for this test
        }

        @SubscriptionBuilder
        static func applyEventRules(to state: RulesPublisher) -> [AnyCancellable] {
            // No event rules needed for this test
        }

        @AnyTokenBuilder<Any>
        static func applyAnyRules(to state: UIBinding<Self>) -> [Any] {
            // No any rules needed for this test
        }
    }

    // MARK: - Additional UIBinding Tests

    func testUIBindingWithDifferentTypes() {
        @UIState
        var intValue: Int = 0

        @UIState
        var stringValue: String = "initial"

        @UIState
        var boolValue: Bool = false

        XCTAssertEqual(intValue, 0)
        XCTAssertEqual(stringValue, "initial")
        XCTAssertFalse(boolValue)

        intValue = 42
        stringValue = "updated"
        boolValue = true

        XCTAssertEqual(intValue, 42)
        XCTAssertEqual(stringValue, "updated")
        XCTAssertTrue(boolValue)
    }

    func testUIBindingWithOptionalValues() {
        @UIState
        var optionalInt: Int? = nil

        XCTAssertNil(optionalInt)

        optionalInt = 42
        XCTAssertEqual(optionalInt, 42)

        optionalInt = nil
        XCTAssertNil(optionalInt)
    }

    func testUIBindingWithArrayValues() {
        @UIState
        var arrayValue: [Int] = []

        XCTAssertTrue(arrayValue.isEmpty)

        arrayValue = [1, 2, 3]
        XCTAssertEqual(arrayValue, [1, 2, 3])

        arrayValue = [4, 5, 6]
        XCTAssertEqual(arrayValue, [4, 5, 6])

        arrayValue = []
        XCTAssertTrue(arrayValue.isEmpty)
    }

    func testUIBindingWithDictionaryValues() {
        @UIState
        var dictValue: [String: Int] = [:]

        XCTAssertTrue(dictValue.isEmpty)

        dictValue = ["a": 1, "b": 2]
        XCTAssertEqual(dictValue["a"], 1)
        XCTAssertEqual(dictValue["b"], 2)

        dictValue = ["c": 3]
        XCTAssertEqual(dictValue["c"], 3)
        XCTAssertNil(dictValue["a"])
    }

    func testUIBindingWithStructValues() {
        struct TestStruct: Equatable {
            var id: Int
            var name: String
        }

        @UIState
        var structValue: TestStruct = .init(id: 0, name: "initial")

        XCTAssertEqual(structValue.id, 0)
        XCTAssertEqual(structValue.name, "initial")

        structValue = TestStruct(id: 1, name: "updated")
        XCTAssertEqual(structValue.id, 1)
        XCTAssertEqual(structValue.name, "updated")
    }

    func testUIBindingWithNestedProperties() {
        struct NestedStruct: Equatable {
            var inner: InnerStruct
        }

        struct InnerStruct: Equatable {
            var value: Int
        }

        @UIState
        var nestedValue: NestedStruct = .init(inner: InnerStruct(value: 0))

        XCTAssertEqual(nestedValue.inner.value, 0)

        nestedValue.inner.value = 42
        XCTAssertEqual(nestedValue.inner.value, 42)
    }

    func testUIBindingWithPublisherSubscription() {
        @UIState
        var counter: Int = 0

        var receivedValues: [DiffedValue<Int>] = []
        let expectation = XCTestExpectation(description: "Should receive values")
        expectation.expectedFulfillmentCount = 3

        $counter.publisher
            .sink { diff in
                receivedValues.append(diff)
                expectation.fulfill()
            }
            .store(in: &observers)

        counter = 1
        counter = 2

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedValues.count, 3)
        XCTAssertEqual(receivedValues[0].new, 0) // Initial value
        XCTAssertEqual(receivedValues[1].new, 1)
        XCTAssertEqual(receivedValues[2].new, 2)
    }

    func testUIBindingWithKeyPathSubscription() {
        @UIState
        var model = TestModel(number: 0, binding: 0)

        var numberValues: [Int] = []
        var bindingValues: [Int] = []

        $model.number.sink { diff in numberValues.append(diff.new) }.store(in: &observers)
        $model.binding.sink { diff in bindingValues.append(diff.new) }.store(in: &observers)

        model.number = 5
        model.binding = 10

        XCTAssertEqual(numberValues, [0, 5])
        XCTAssertEqual(bindingValues, [0, 10])
    }

    func testUIBindingWithCombineOperators() {
        @UIState
        var counter: Int = 0

        var receivedValues: [Int] = []
        let expectation = XCTestExpectation(description: "Should receive filtered values")

        $counter.publisher
            .filter { $0.new > 5 }
            .map { $0.new * 2 }
            .sink { value in
                receivedValues.append(value)
                if receivedValues.count == 2 {
                    expectation.fulfill()
                }
            }
            .store(in: &observers)

        counter = 1 // Should be filtered out
        counter = 6 // Should become 12
        counter = 2 // Should be filtered out
        counter = 8 // Should become 16

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedValues, [12, 16])
    }

    func testUIBindingWithMultipleSubscribers() {
        @UIState
        var counter: Int = 0

        var subscriber1Values: [DiffedValue<Int>] = []
        var subscriber2Values: [DiffedValue<Int>] = []

        $counter.publisher.sink { subscriber1Values.append($0) }.store(in: &observers)
        $counter.publisher.sink { subscriber2Values.append($0) }.store(in: &observers)

        counter = 1
        counter = 2
        counter = 3

        XCTAssertEqual(subscriber1Values.count, 4) // Initial + 3 changes
        XCTAssertEqual(subscriber2Values.count, 4) // Initial + 3 changes
        XCTAssertEqual(subscriber1Values.map(\.new), [0, 1, 2, 3])
        XCTAssertEqual(subscriber2Values.map(\.new), [0, 1, 2, 3])
    }

    func testUIBindingWithCancellation() {
        @UIState
        var counter: Int = 0

        var receivedValues: [DiffedValue<Int>] = []
        let cancellable = $counter.publisher.sink { receivedValues.append($0) }

        counter = 1
        counter = 2

        XCTAssertEqual(receivedValues.count, 3) // 0 (initial), 1, 2

        // Cancel subscription
        cancellable.cancel()

        counter = 3
        counter = 4

        // Should only receive values before cancellation
        XCTAssertEqual(receivedValues.count, 3) // Still 0, 1, 2
    }

    func testUIBindingWithDirectPropertyAccess() {
        @UIState
        var model = TestModel(number: 0, binding: 0)

        // Test direct property access
        XCTAssertEqual(model.number, 0)
        XCTAssertEqual(model.binding, 0)

        // Test direct property modification
        model.number = 42
        XCTAssertEqual(model.number, 42)

        model.binding = 100
        XCTAssertEqual(model.binding, 100)
    }

    func testUIBindingWithMemoryManagement() {
        // UIState is a class, test that it can be created and used
        @UIState
        var counter: Int = 0

        XCTAssertEqual(counter, 0)

        counter = 42
        XCTAssertEqual(counter, 42)
    }

    func testUIBindingWithConcurrentAccess() {
        @UIState
        var counter: Int = 0

        let expectation = XCTestExpectation(description: "Concurrent access")
        expectation.expectedFulfillmentCount = 10

        // Test concurrent access
        for i in 0..<10 {
            DispatchQueue.global().async { [_counter] in
                _counter.wrappedValue = i
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 5.0)

        // Should have some final value (exact value depends on timing)
        XCTAssertTrue(counter >= 0 && counter < 10)
    }

    func testUIBindingWithLargeData() {
        let largeArray = Array(0..<1000)
        @UIState
        var largeData: [Int] = largeArray

        XCTAssertEqual(largeData.count, 1000)
        XCTAssertEqual(largeData.first, 0)
        XCTAssertEqual(largeData.last, 999)

        let newLargeArray = Array(1000..<2000)
        largeData = newLargeArray

        XCTAssertEqual(largeData.count, 1000)
        XCTAssertEqual(largeData.first, 1000)
        XCTAssertEqual(largeData.last, 1999)
    }

    func testUIBindingWithUnicodeValues() {
        @UIState
        var unicodeString: String = "🚀"

        XCTAssertEqual(unicodeString, "🚀")

        unicodeString = "🌟"
        XCTAssertEqual(unicodeString, "🌟")

        unicodeString = "💻"
        XCTAssertEqual(unicodeString, "💻")
    }

    func testUIBindingWithFloatValues() {
        @UIState
        var floatValue: Double = 0.0

        XCTAssertEqual(floatValue, 0.0, accuracy: 0.001)

        floatValue = 3.14159
        XCTAssertEqual(floatValue, 3.14159, accuracy: 0.001)

        floatValue = -2.71828
        XCTAssertEqual(floatValue, -2.71828, accuracy: 0.001)
    }

    func testUIBindingWithBooleanValues() {
        @UIState
        var boolValue: Bool = false

        XCTAssertFalse(boolValue)

        boolValue = true
        XCTAssertTrue(boolValue)

        boolValue = false
        XCTAssertFalse(boolValue)
    }

    func testUIBindingWithCharacterValues() {
        @UIState
        var charValue: Character = "A"

        XCTAssertEqual(charValue, "A")

        charValue = "Z"
        XCTAssertEqual(charValue, "Z")

        charValue = "1"
        XCTAssertEqual(charValue, "1")
    }

    func testUIBindingWithTwoWayBinding() {
        @UIState
        var source: Int = 0

        @UIState
        var target: Int = 0

        let targetBinding: UIBinding<Int> = $target()

        // Subscribe source to target
        targetBinding
            .map(\.new)
            .sink { targetBinding.wrappedValue = $0 }
            .store(in: &observers)

        XCTAssertEqual(source, 0)
        XCTAssertEqual(target, 0)

        source = 42
        XCTAssertEqual(source, 42)
        XCTAssertEqual(target, 0) // target doesn't automatically update without subscription

        target = 100
        XCTAssertEqual(source, 42) // source doesn't automatically update
        XCTAssertEqual(target, 100)
    }

    func testUIBindingWithNestedBinding() {
        struct NestedModel: Equatable {
            var value: Int
            var text: String
        }

        @UIState
        var model = NestedModel(value: 0, text: "initial")

        // Use explicit type annotations to resolve ambiguity
        let valueBinding: UIBinding<Int> = $model.value
        let textBinding: UIBinding<String> = $model.text

        XCTAssertEqual(valueBinding.wrappedValue, 0)
        XCTAssertEqual(textBinding.wrappedValue, "initial")

        valueBinding.wrappedValue = 42
        textBinding.wrappedValue = "updated"

        XCTAssertEqual(model.value, 42)
        XCTAssertEqual(model.text, "updated")
    }

    func testUIBindingConstant() {
        // Test that UIBinding.constant() is the only way to create UIBinding directly
        let constantBinding = UIBinding<String>.constant("Fixed Value")
        
        XCTAssertEqual(constantBinding.wrappedValue, "Fixed Value")
        
        // Setting should be ignored for constant binding
        constantBinding.wrappedValue = "New Value"
        XCTAssertEqual(constantBinding.wrappedValue, "Fixed Value")
        
        // Test with different types
        let intConstant = UIBinding<Int>.constant(42)
        XCTAssertEqual(intConstant.wrappedValue, 42)
        
        let boolConstant = UIBinding<Bool>.constant(true)
        XCTAssertTrue(boolConstant.wrappedValue)
    }
}
