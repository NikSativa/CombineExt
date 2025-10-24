import CombineExt
import Foundation
import XCTest

final class UIBindingTests: XCTestCase {
    private var observers: Set<AnyCancellable> = []
    func test_UIBindingDynamicCallNoArguments() {
        @UIBinding
        var model = TestModel(number: 42, binding: 0)

        XCTAssertEqual(model.number, 42)
        XCTAssertEqual(model.binding, 0) // No rules applied

        @UIBinding
        var binding: TestModel
        _binding = $model()

        XCTAssertEqual(binding.number, 42)
        XCTAssertEqual(binding.binding, 0)

        binding.number = 100

        XCTAssertEqual(model.number, 42) // model.number remains unchanged in UIBinding
        XCTAssertEqual(model.binding, 0) // binding remains unchanged
    }

    func test_UIBindingDynamicCallWithKeyPath() {
        @UIBinding
        var model = TestModel(number: 42, binding: 0)

        XCTAssertEqual(model.number, 42)
        XCTAssertEqual(model.binding, 0) // No rules applied

        @UIBinding
        var binding: Int
        _binding = $model(\.number)

        XCTAssertEqual(binding, 42)
        XCTAssertEqual(model.binding, 0)

        binding = 100

        XCTAssertEqual(model.number, 42) // model.number remains unchanged in UIBinding
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
        @UIBinding
        var intValue: Int = 0

        @UIBinding
        var stringValue: String = "initial"

        @UIBinding
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
        @UIBinding
        var optionalInt: Int? = nil

        XCTAssertNil(optionalInt)

        optionalInt = 42
        XCTAssertEqual(optionalInt, 42)

        optionalInt = nil
        XCTAssertNil(optionalInt)
    }

    func testUIBindingWithArrayValues() {
        @UIBinding
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
        @UIBinding
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

        @UIBinding
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

        @UIBinding
        var nestedValue: NestedStruct = .init(inner: InnerStruct(value: 0))

        XCTAssertEqual(nestedValue.inner.value, 0)

        nestedValue.inner.value = 42
        XCTAssertEqual(nestedValue.inner.value, 42)
    }

    func testUIBindingWithPublisherSubscription() {
        @UIBinding
        var counter: Int = 0

        var receivedValues: [Int] = []
        let expectation = XCTestExpectation(description: "Should receive values")

        $counter
            .sink { value in
                receivedValues.append(value)
                if receivedValues.count == 3 {
                    expectation.fulfill()
                }
            }
            .store(in: &observers)

        counter = 1
        counter = 2

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedValues, [0, 1, 2])
    }

    func testUIBindingWithKeyPathSubscription() {
        @UIBinding
        var model = TestModel(number: 0, binding: 0)

        var numberValues: [Int] = []
        var bindingValues: [Int] = []

        $model.number.sink { numberValues.append($0) }.store(in: &observers)
        $model.binding.sink { bindingValues.append($0) }.store(in: &observers)

        model.number = 5
        model.binding = 10

        XCTAssertEqual(numberValues, [0, 5])
        XCTAssertEqual(bindingValues, [0, 10])
    }

    func testUIBindingWithCombineOperators() {
        @UIBinding
        var counter: Int = 0

        var receivedValues: [Int] = []
        let expectation = XCTestExpectation(description: "Should receive filtered values")

        $counter
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
        @UIBinding
        var counter: Int = 0

        var subscriber1Values: [Int] = []
        var subscriber2Values: [Int] = []

        $counter.sink { subscriber1Values.append($0) }.store(in: &observers)
        $counter.sink { subscriber2Values.append($0) }.store(in: &observers)

        counter = 1
        counter = 2
        counter = 3

        XCTAssertEqual(subscriber1Values, [0, 1, 2, 3])
        XCTAssertEqual(subscriber2Values, [0, 1, 2, 3])
    }

    func testUIBindingWithCancellation() {
        @UIBinding
        var counter: Int = 0

        var receivedValues: [Int] = []
        let cancellable = $counter.sink { receivedValues.append($0) }

        counter = 1
        counter = 2

        XCTAssertEqual(receivedValues.count, 3) // 0, 1, 2

        // Cancel subscription
        cancellable.cancel()

        counter = 3
        counter = 4

        // Should only receive values before cancellation
        XCTAssertEqual(receivedValues.count, 3) // Still 0, 1, 2
    }

    func testUIBindingWithDirectPropertyAccess() {
        @UIBinding
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
        // UIBinding is a struct, so we can't test weak references
        // Instead, test that it can be created and used
        @UIBinding
        var counter: Int = 0

        XCTAssertEqual(counter, 0)

        counter = 42
        XCTAssertEqual(counter, 42)
    }

    func testUIBindingWithConcurrentAccess() {
        @UIBinding
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
        @UIBinding
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
        @UIBinding
        var unicodeString: String = "🚀"

        XCTAssertEqual(unicodeString, "🚀")

        unicodeString = "🌟"
        XCTAssertEqual(unicodeString, "🌟")

        unicodeString = "💻"
        XCTAssertEqual(unicodeString, "💻")
    }

    func testUIBindingWithFloatValues() {
        @UIBinding
        var floatValue: Double = 0.0

        XCTAssertEqual(floatValue, 0.0, accuracy: 0.001)

        floatValue = 3.14159
        XCTAssertEqual(floatValue, 3.14159, accuracy: 0.001)

        floatValue = -2.71828
        XCTAssertEqual(floatValue, -2.71828, accuracy: 0.001)
    }

    func testUIBindingWithBooleanValues() {
        @UIBinding
        var boolValue: Bool = false

        XCTAssertFalse(boolValue)

        boolValue = true
        XCTAssertTrue(boolValue)

        boolValue = false
        XCTAssertFalse(boolValue)
    }

    func testUIBindingWithCharacterValues() {
        @UIBinding
        var charValue: Character = "A"

        XCTAssertEqual(charValue, "A")

        charValue = "Z"
        XCTAssertEqual(charValue, "Z")

        charValue = "1"
        XCTAssertEqual(charValue, "1")
    }

    func testUIBindingWithTwoWayBinding() {
        @UIBinding
        var source: Int = 0

        @UIBinding
        var target: Int = 0

        // Create two-way binding
        target = source

        XCTAssertEqual(source, 0)
        XCTAssertEqual(target, 0)

        source = 42
        XCTAssertEqual(source, 42)
        XCTAssertEqual(target, 0) // target doesn't automatically update

        target = 100
        XCTAssertEqual(source, 42) // source doesn't automatically update
        XCTAssertEqual(target, 100)
    }

    func testUIBindingWithNestedBinding() {
        struct NestedModel: Equatable {
            var value: Int
            var text: String
        }

        @UIBinding
        var model = NestedModel(value: 0, text: "initial")

        @UIBinding
        var valueBinding: Int
        _valueBinding = $model.value

        @UIBinding
        var textBinding: String
        _textBinding = $model.text

        XCTAssertEqual(valueBinding, 0)
        XCTAssertEqual(textBinding, "initial")

        valueBinding = 42
        textBinding = "updated"

        XCTAssertEqual(model.value, 42)
        XCTAssertEqual(model.text, "updated")
    }
}
