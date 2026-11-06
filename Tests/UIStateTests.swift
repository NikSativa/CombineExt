import CombineExt
import Foundation
import SwiftUI
import XCTest

final class UIStateTests: XCTestCase {
    @UIState
    private var subject: State = .init()
    private var observers: Set<AnyCancellable> = []
    private var rootStates: [State] = []

    override func setUp() {
        super.setUp()
        $subject.sink { [unowned self] state in
            rootStates.append(state)
        }
        .store(in: &observers)
    }

    func testShouldFireSubscriptionImmediately() {
        let expected: [State] = [
            .init(counter: -1, toggle: false)
        ]
        XCTAssertEqual(rootStates, expected)
    }

    func testShouldFireSubscriptionOnAnyChanges() {
        subject.toggle.toggle()
        subject.counter += 1
        subject.counter += 1

        let expected: [State] = [
            .init(counter: -1, toggle: false),
            .init(counter: -1, toggle: true),
            .init(counter: 0, toggle: true),
            .init(counter: 1, toggle: true)
        ]
        XCTAssertEqual(rootStates, expected)
    }

    func testShouldFireSubscriptionForKeyPath() {
        var expected: [State] = []

        @UIBinding
        var newCounterSubject: Int
        _newCounterSubject = $subject.observe(\.counter)

        var newCounterStates: [Int] = []
        $newCounterSubject.sink { state in
            newCounterStates.append(state)
        }
        .store(in: &observers)
        expected.append(.init(counter: -1, toggle: false)) // initial
        XCTAssertEqual(newCounterSubject, subject.counter)

        subject.toggle.toggle()
        expected.append(.init(counter: -1, toggle: true))
        subject.counter += 1
        expected.append(.init(counter: 0, toggle: true))
        subject.counter += 1
        expected.append(.init(counter: 1, toggle: true))

        newCounterSubject = 5
        expected.append(.init(counter: 5, toggle: true))
        newCounterSubject = 3
        expected.append(.init(counter: 3, toggle: true))

        @UIBinding
        var newSecondCounterSubject: Int
        _newSecondCounterSubject = $subject.observe(\.counter)

        var newSecondCounterStates: [Int] = []
        $newSecondCounterSubject.sink { state in
            newSecondCounterStates.append(state)
        }
        .store(in: &observers)
        XCTAssertEqual(newSecondCounterSubject, subject.counter)

        @UIBinding
        var newToggleSubject: Bool
        _newToggleSubject = $subject.observe(\.toggle)

        var newToggleStates: [Bool] = []
        $newToggleSubject.sink { state in
            newToggleStates.append(state)
        }
        .store(in: &observers)
        XCTAssertEqual(newToggleSubject, subject.toggle)

        let dropFirstForNewObserver = expected.count - 1

        subject.counter += 1
        expected.append(.init(counter: 4, toggle: true))
        subject.counter -= 1
        expected.append(.init(counter: 3, toggle: true))
        subject.counter -= 1
        expected.append(.init(counter: 2, toggle: true))
        subject.toggle.toggle()
        expected.append(.init(counter: 2, toggle: false))

        newCounterSubject += 1
        expected.append(.init(counter: 3, toggle: false))
        newCounterSubject = 22
        expected.append(.init(counter: 22, toggle: false))

        newSecondCounterSubject = 55
        expected.append(.init(counter: 55, toggle: false))
        newSecondCounterSubject = -11
        expected.append(.init(counter: -11, toggle: false))

        newToggleSubject.toggle()
        expected.append(.init(counter: -11, toggle: true))
        newSecondCounterSubject = 1
        expected.append(.init(counter: 1, toggle: true))
        newToggleSubject.toggle()
        expected.append(.init(counter: 1, toggle: false))

        XCTAssertEqual(rootStates, expected)

        let expectedCounterStates: [Int] = expected.map(\.counter)
        XCTAssertEqual(newCounterStates, expectedCounterStates)
        XCTAssertEqual(newCounterSubject, subject.counter)

        let expectedSecondCounterStates: [Int] = expected.dropFirst(dropFirstForNewObserver).map(\.counter)
        XCTAssertEqual(newSecondCounterStates, expectedSecondCounterStates)
        XCTAssertEqual(newSecondCounterSubject, subject.counter)

        let expectedBoolStates: [Bool] = expected.dropFirst(dropFirstForNewObserver).map(\.toggle)
        XCTAssertEqual(newToggleStates, expectedBoolStates)
        XCTAssertEqual(newToggleSubject, subject.toggle)
    }

    func test_nested_array() {
        @UIBinding
        var second: Int
        _second = $subject.ui.list.unsafe(1)

        var listStates: [Int] = []
        _second.sink { state in
            listStates.append(state)
        }
        .store(in: &observers)

        subject.toggle.toggle()
        subject.counter += 1
        subject.counter += 1
        subject.list = [0]
        subject.list = [0, 1]
        subject.list = [0, 1, 2]
        subject.list = [0, 1]
        subject.list = [0]
        subject.list = [0, 3]
        subject.list = [0, 3, 1]

        second = 5
        second = 6

        let expected: [State] = [
            .init(counter: -1, toggle: false),
            .init(counter: -1, toggle: true),
            .init(counter: 0, toggle: true),
            .init(counter: 1, toggle: true),
            .init(counter: 1, toggle: true, list: [0]),
            .init(counter: 1, toggle: true, list: [0, 1]),
            .init(counter: 1, toggle: true, list: [0, 1, 2]),
            .init(counter: 1, toggle: true, list: [0, 1]),
            .init(counter: 1, toggle: true, list: [0]),
            .init(counter: 1, toggle: true, list: [0, 3]),
            .init(counter: 1, toggle: true, list: [0, 3, 1]),
            .init(counter: 1, toggle: true, list: [0, 5, 1]),
            .init(counter: 1, toggle: true, list: [0, 6, 1])
        ]

        XCTAssertEqual(rootStates, expected)
        XCTAssertEqual(listStates, [1, 1, 1, 3, 3, 5, 6])
    }

    func test_root_array() {
        @UIState
        var subject: [Int] = []

        var rootStates: [[Int]] = []
        $subject.sink { state in
            rootStates.append(state)
        }
        .store(in: &observers)

        @UIBinding
        var second: Int
        _second = $subject.unsafe(1)

        var listStates: [Int] = []
        _second.sink { state in
            listStates.append(state)
        }
        .store(in: &observers)

        subject = [0]
        subject = [0, 1]
        subject = [0, 1, 2]
        subject = [0, 1]
        subject = [0]
        subject = [0, 3]
        subject = [0, 3, 1]

        second = 5
        second = 6

        let expected: [[Int]] = [
            [],
            [0],
            [0, 1],
            [0, 1, 2],
            [0, 1],
            [0],
            [0, 3],
            [0, 3, 1],
            [0, 5, 1],
            [0, 6, 1]
        ]

        XCTAssertEqual(rootStates, expected)
        XCTAssertEqual(listStates, [1, 1, 1, 3, 3, 5, 6])
    }
}

extension UIStateTests {
    func test_UIStateDynamicCallNoArguments() {
        @UIState
        var model = TestModel(number: 42, binding: 0)

        XCTAssertEqual(model.number, 42)
        XCTAssertEqual(model.binding, 0) // No rules applied

        @UIBinding
        var binding: TestModel
        _binding = $model()

        XCTAssertEqual(binding.number, 42)
        XCTAssertEqual(binding.binding, 0)

        binding.number = 100

        XCTAssertEqual(model.number, 100)
        XCTAssertEqual(model.binding, 0) // binding remains unchanged
    }

    func test_UIStateDynamicCallWithKeyPath() {
        @UIState
        var model = TestModel(number: 42, binding: 0)

        XCTAssertEqual(model.number, 42)
        XCTAssertEqual(model.binding, 0) // No rules applied

        @UIBinding
        var binding: Int
        _binding = $model(\.number)

        XCTAssertEqual(binding, 42)
        XCTAssertEqual(model.binding, 0)

        binding = 100

        XCTAssertEqual(model.number, 100)
        XCTAssertEqual(model.binding, 0) // binding remains unchanged
    }

    func testSubscriptReadsProperty() {
        subject.list = [1, 2, 3]

        XCTAssertEqual($subject[\.counter], -1)
        XCTAssertEqual($subject[\.list[1]], 2)
        XCTAssertEqual($subject[\.list.count], 3)
    }

    func testDynamicMemberGivesSwiftUIBinding() {
        let counter: Binding<Int> = $subject.counter

        counter.wrappedValue = 5
        counter.wrappedValue = 5

        XCTAssertEqual(counter.wrappedValue, 5)
        XCTAssertEqual(subject.counter, 5)
        XCTAssertEqual(rootStates, [
            .init(counter: -1, toggle: false),
            .init(counter: 5, toggle: false)
        ])
    }

    func testUIGivesBindingToProperty() {
        var counters: [Int] = []
        let counter: UIBinding<Int> = $subject.ui.counter
        counter.sink { diff in
            counters.append(diff.new)
        }
        .store(in: &observers)

        counter.wrappedValue = 5

        XCTAssertEqual(subject.counter, 5)
        XCTAssertEqual(counter.wrappedValue, 5)
        XCTAssertEqual(counters, [-1, 5])
    }

    func testWithLockKeepsEveryConcurrentWrite() {
        let state = UIState(wrappedValue: State())
        let iterations = 200

        DispatchQueue.concurrentPerform(iterations: iterations) { _ in
            state.withLock { value in
                value.counter += 1
            }
        }

        XCTAssertEqual(state[\.counter], iterations - 1)
    }

    func testCustomLockProtectsEachReadAndWrite() {
        let lock = RecordingLock()
        let state = UIState(wrappedValue: State(), lock: .custom(lock))

        _ = state.wrappedValue
        XCTAssertEqual(lock.lockCount, 1)

        state.wrappedValue.counter = 5
        XCTAssertEqual(lock.lockCount, 3)
        XCTAssertEqual(lock.maxDepth, 1)
    }

    func testStateUsesDefaultLockWhenInitializerGetsNoLock() {
        let lock = RecordingLock()
        let defaultLock = StateDefaultLock
        StateDefaultLock = .custom(lock)
        defer {
            StateDefaultLock = defaultLock
        }

        let state = UIState(wrappedValue: 0)
        _ = state.wrappedValue

        XCTAssertEqual(lock.lockCount, 1)
    }

    func testConcurrentFirstAccessToPublisherIsSafe() {
        let state = UIState(wrappedValue: 0)

        DispatchQueue.concurrentPerform(iterations: 100) { _ in
            _ = state.publisher
        }

        var values: [Int] = []
        let cancellable = state.publisher.sink { diff in
            values.append(diff.new)
        }
        state.wrappedValue = 1

        XCTAssertEqual(values, [0, 1])
        cancellable.cancel()
    }

    func testUIStateWithDifferentTypes() {
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

    func testUIStateWithOptionalValues() {
        @UIState
        var optionalInt: Int? = nil

        XCTAssertNil(optionalInt)

        optionalInt = 42
        XCTAssertEqual(optionalInt, 42)

        optionalInt = nil
        XCTAssertNil(optionalInt)
    }

    func testUIStateWithArrayValues() {
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

    func testUIStateWithDictionaryValues() {
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

    func testUIStateWithStructValues() {
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

    func testUIStateWithNestedProperties() {
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

    func testUIStateWithPublisherSubscription() {
        @UIState
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

    func testUIStateWithKeyPathSubscription() {
        @UIState
        var model = TestModel(number: 0, binding: 0)

        var numberValues: [Int] = []
        var bindingValues: [Int] = []

        $model.ui.number.sink { numberValues.append($0) }.store(in: &observers)
        $model.ui.binding.sink { bindingValues.append($0) }.store(in: &observers)

        model.number = 5
        model.binding = 10

        XCTAssertEqual(numberValues, [0, 5, 5])
        XCTAssertEqual(bindingValues, [0, 0, 10])
    }

    func testUIStateWithCombineOperators() {
        @UIState
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

    func testUIStateWithMultipleSubscribers() {
        @UIState
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

    func testUIStateWithCancellation() {
        @UIState
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

    func testUIStateWithDirectPropertyAccess() {
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

    func testUIStateWithMemoryManagement() {
        weak var weakUIState: UIState<Int>?

        do {
            let uiState = UIState(wrappedValue: 0)
            weakUIState = uiState

            var cancellables = Set<AnyCancellable>()
            uiState.sink { _ in }.store(in: &cancellables)
            uiState.wrappedValue = 1
        }

        // UIState should be deallocated
        XCTAssertNil(weakUIState)
    }

    func testUIStateWithConcurrentAccess() {
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

    func testUIStateWithLargeData() {
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

    func testUIStateWithUnicodeValues() {
        @UIState
        var unicodeString: String = "🚀"

        XCTAssertEqual(unicodeString, "🚀")

        unicodeString = "🌟"
        XCTAssertEqual(unicodeString, "🌟")

        unicodeString = "💻"
        XCTAssertEqual(unicodeString, "💻")
    }

    func testUIStateWithFloatValues() {
        @UIState
        var floatValue: Double = 0.0

        XCTAssertEqual(floatValue, 0.0, accuracy: 0.001)

        floatValue = 3.14159
        XCTAssertEqual(floatValue, 3.14159, accuracy: 0.001)

        floatValue = -2.71828
        XCTAssertEqual(floatValue, -2.71828, accuracy: 0.001)
    }

    func testUIStateWithBooleanValues() {
        @UIState
        var boolValue: Bool = false

        XCTAssertFalse(boolValue)

        boolValue = true
        XCTAssertTrue(boolValue)

        boolValue = false
        XCTAssertFalse(boolValue)
    }

    func testUIStateWithCharacterValues() {
        @UIState
        var charValue: Character = "A"

        XCTAssertEqual(charValue, "A")

        charValue = "Z"
        XCTAssertEqual(charValue, "Z")

        charValue = "1"
        XCTAssertEqual(charValue, "1")
    }
}

private extension UIStateTests {
    struct State: Equatable {
        var counter: Int = -1
        var toggle: Bool = false
        var list: [Int] = []
    }

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
}
