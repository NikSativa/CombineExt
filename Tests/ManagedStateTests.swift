import Combine
import CombineExt
import XCTest

final class ManagedStateTests: XCTestCase {
    @ManagedState
    var subject: TestModel = .init()
    var cancellables: Set<AnyCancellable>!
    var models: [TestModel] = []
    var numbers: [Int] = []
    var binding: [Int] = []
    var texts: [String] = []

    override func setUp() {
        super.setUp()
        cancellables = []
        clearValues()

        @ManagedState
        var subject: TestModel = .init()
    }

    override func tearDown() {
        super.tearDown()
        cancellables = nil
    }

    private func clearValues() {
        models = []
        numbers = []
        texts = []
    }

    private func subscribe() {
        $subject.observe(\.self)
            .sink { new in
                self.models.append(new)
            }
            .store(in: &cancellables)

        $subject.number
            .sink { new in
                self.numbers.append(new)
            }
            .store(in: &cancellables)

        $subject.binding
            .sink { new in
                self.binding.append(new)
            }
            .store(in: &cancellables)

        $subject.text
            .sink { new in
                self.texts.append(new)
            }
            .store(in: &cancellables)
    }

    func testClosureCapturing() {
        let some: () -> Void = { [_subject] in
            print("ignore me. \(_subject.number as Int)")
        }
        some()
    }

    func testEditable() async throws {
        subscribe()

        // initial
        XCTAssertEqual(models, [.init(text: "0")])
        XCTAssertEqual(numbers, [0])
        XCTAssertEqual(binding, [0])
        XCTAssertEqual(texts, ["0"])

        // actions
        var exps: [XCTestExpectation] = []
        for idx in 0..<4 {
            let exp = expectation(description: "incrementer")
            exps.append(exp)
            DispatchQueue.global().async { [_subject] in
                _subject.number = idx + 1
                exp.fulfill()
            }
        }

        await fulfillment(of: exps)

        XCTAssertEqual(numbers.count, 5)
        XCTAssertTrue(numbers.contains(subject.number))
        XCTAssertTrue(texts.contains(subject.text))

        XCTAssertEqual(Set(models), Set([
            .init(number: 0, binding: 0),
            .init(number: 1, binding: 1),
            .init(number: 2, binding: 2),
            .init(number: 3, binding: 3),
            .init(number: 4, binding: 4)
        ]))
        XCTAssertEqual(numbers.sorted(), [0, 1, 2, 3, 4])
        XCTAssertEqual(binding.sorted(), [0, 1, 2, 3, 4])
        XCTAssertEqual(texts.sorted(), ["0", "1", "2", "3", "4"])

        XCTAssertTrue([1, 2, 3, 4].contains(subject.number))
        XCTAssertTrue(["1", "2", "3", "4"].contains(subject.text))
    }

    func testWithLock() async throws {
        subscribe()

        // initial
        XCTAssertEqual(models, [.init(text: "0")])
        XCTAssertEqual(numbers, [0])
        XCTAssertEqual(binding, [0])
        XCTAssertEqual(texts, ["0"])

        // Test withLock for atomic operations
        var exps: [XCTestExpectation] = []
        for _ in 0..<4 {
            let exp = expectation(description: "withLock incrementer")
            exps.append(exp)
            DispatchQueue.global().async { [_subject] in
                _subject.withLock { value in
                    value.number += 1
                }
                exp.fulfill()
            }
        }

        await fulfillment(of: exps)

        XCTAssertEqual(numbers.count, 5)
        XCTAssertTrue(numbers.contains(subject.number))
        XCTAssertTrue(texts.contains(subject.text))

        XCTAssertEqual(Set(models), Set([
            .init(number: 0, binding: 0),
            .init(number: 1, binding: 1),
            .init(number: 2, binding: 2),
            .init(number: 3, binding: 3),
            .init(number: 4, binding: 4)
        ]))
        XCTAssertEqual(numbers, [0, 1, 2, 3, 4])
        XCTAssertEqual(binding, [0, 1, 2, 3, 4])
        XCTAssertEqual(texts, ["0", "1", "2", "3", "4"])

        XCTAssertEqual(subject.number, 4)
        XCTAssertEqual(subject.text, "4")
    }

    func testWithLockComplexOperations() {
        subscribe()

        // Test complex operations within withLock
        _subject.withLock { value in
            value.number = 10
            // binding will be automatically set to 10 by applyRules
            // text will be updated by applyRules to "10"
        }

        XCTAssertEqual(subject.number, 10)
        XCTAssertEqual(subject.binding, 10) // binding is automatically set to number
        XCTAssertEqual(subject.text, "10")

        // Verify that all changes were captured
        XCTAssertEqual(numbers, [0, 10])
        XCTAssertEqual(binding, [0, 10]) // binding follows number
        XCTAssertEqual(texts, ["0", "10"])
    }

    func testWithLockNoChange() {
        subscribe()

        let initialCount = numbers.count

        // withLock with no actual changes should not trigger updates
        _subject.withLock { _ in
            // No changes made
        }

        // Should not have triggered any additional updates
        XCTAssertEqual(numbers.count, initialCount)
        XCTAssertEqual(subject.number, 0)
        XCTAssertEqual(subject.text, "0")
    }

    func testInitialization() {
        XCTAssertEqual(subject.number, 0)
        XCTAssertEqual(subject.text, "0")
        XCTAssertEqual(models, [])
        XCTAssertEqual(numbers, [])
        XCTAssertEqual(texts, [])
    }

    func testSink() async throws {
        subscribe()

        // initial
        XCTAssertEqual(models, [.init(text: "0")])
        XCTAssertEqual(numbers, [0])
        XCTAssertEqual(binding, [0])
        XCTAssertEqual(texts, ["0"])

        subject.number = 1

        // updated
        XCTAssertEqual(models, [
            .init(number: 0, binding: 0),
            .init(number: 1, binding: 1)
        ])
        XCTAssertEqual(numbers, [0, 1])
        XCTAssertEqual(binding, [0, 1])
        XCTAssertEqual(texts, ["0", "1"])

        subject.number += 1
        subject.number += 1
        subject.number += 1

        XCTAssertEqual(models, [
            .init(number: 0, binding: 0),
            .init(number: 1, binding: 1),
            .init(number: 2, binding: 2),
            .init(number: 3, binding: 3),
            .init(number: 4, binding: 4)
        ])
        XCTAssertEqual(numbers, [0, 1, 2, 3, 4])
        XCTAssertEqual(texts, ["0", "1", "2", "3", "4"])

        XCTAssertEqual(subject.number, 4)
        XCTAssertEqual(subject.text, "4")
    }

    func testCounter() {
        @ManagedState
        var state: CounterModel = .init()
        // state.value += 1 // 0
        XCTAssertEqual(state.valueFunc, 0)
        XCTAssertEqual(state.valueBind, 0)
        XCTAssertEqual(CounterModel.counterFunc, 1)
        XCTAssertEqual(CounterModel.counterBind, 1)

        state.value += 1 // 1
        XCTAssertEqual(state.valueFunc, 2)
        XCTAssertEqual(state.valueBind, 3)
        XCTAssertEqual(CounterModel.counterFunc, 3)
        XCTAssertEqual(CounterModel.counterBind, 2)

        state.value += 1 // 2
        XCTAssertEqual(state.valueFunc, 4)
        XCTAssertEqual(state.valueBind, 6)
        XCTAssertEqual(CounterModel.counterFunc, 5)
        XCTAssertEqual(CounterModel.counterBind, 3)

        state.value += 1 // 3
        XCTAssertEqual(state.valueFunc, 6)
        XCTAssertEqual(state.valueBind, 9)
        XCTAssertEqual(CounterModel.counterFunc, 7)
        XCTAssertEqual(CounterModel.counterBind, 4)
    }
}

private struct CounterModel: BehavioralStateContract {
    var value: Int = 0

    var valueFunc: Int = 0
    var valueBind: Int = 0

    #if swift(>=6.0)
    nonisolated(unsafe) static var counterFunc: Int = 0
    nonisolated(unsafe) static var counterBind: Int = 0
    #else
    static var counterFunc: Int = 0
    static var counterBind: Int = 0
    #endif

    mutating func applyRules() {
        Self.counterFunc += 1
        valueFunc = value * 2
    }

    @SubscriptionBuilder
    static func applyBindingRules(to state: RulesPublisher) -> [AnyCancellable] {
        state.bind(to: \.value) { parent in
            counterBind += 1
            parent.valueBind = parent.value * 3
        }
    }

    @AnyTokenBuilder<Any>
    static func applyAnyRules(to state: UIBinding<Self>) -> [Any] {}
}

// MARK: - DynamicCall Tests for ManagedState

extension ManagedStateTests {
    func test_ManagedStateDynamicCallNoArguments() {
        @ManagedState
        var model = TestModel(number: 42, binding: 0)

        XCTAssertEqual(model.number, 42)
        XCTAssertEqual(model.binding, 42)

        @UIBinding
        var binding: TestModel
        _binding = $model()

        XCTAssertEqual(binding.number, 42)
        XCTAssertEqual(binding.binding, 42)

        binding.number = 100

        XCTAssertEqual(model.number, 100)
        XCTAssertEqual(model.binding, 100)
    }

    func test_ManagedStateDynamicCallWithKeyPath() {
        @ManagedState
        var model = TestModel(number: 42, binding: 0)

        XCTAssertEqual(model.number, 42)
        XCTAssertEqual(model.binding, 42)

        @UIBinding
        var binding: Int
        _binding = $model(\.number)

        XCTAssertEqual(binding, 42)
        XCTAssertEqual(model.binding, 42)

        binding = 100

        XCTAssertEqual(model.number, 100)
        XCTAssertEqual(model.binding, 100)
    }

    // MARK: - Additional ManagedState Tests

    func testManagedStateWithDifferentLockTypes() {
        // Test with absent lock
        @ManagedState(lock: .absent)
        var model1 = TestModel(number: 0, binding: 0)

        XCTAssertEqual(model1.number, 0)
        XCTAssertEqual(model1.binding, 0)

        model1.number = 10
        XCTAssertEqual(model1.number, 10)
        XCTAssertEqual(model1.binding, 10)

        // Test with synced lock
        @ManagedState(lock: .synced)
        var model2 = TestModel(number: 0, binding: 0)

        XCTAssertEqual(model2.number, 0)
        XCTAssertEqual(model2.binding, 0)

        model2.number = 20
        XCTAssertEqual(model2.number, 20)
        XCTAssertEqual(model2.binding, 20)

        // Test with custom lock
        @ManagedState(lock: .custom(NSRecursiveLock()))
        var model3 = TestModel(number: 0, binding: 0)

        XCTAssertEqual(model3.number, 0)
        XCTAssertEqual(model3.binding, 0)

        model3.number = 30
        XCTAssertEqual(model3.number, 30)
        XCTAssertEqual(model3.binding, 30)
    }

    func testManagedStateWithComplexRules() {
        struct ComplexModel: BehavioralStateContract {
            var count: Int = 0
            var isEven: Bool = false
            var displayText: String = ""
            var lastUpdated: Date = .init()

            mutating func applyRules() {
                isEven = count % 2 == 0
                displayText = "Count: \(count)"
                lastUpdated = Date()
            }

            @SubscriptionBuilder
            static func applyBindingRules(to state: RulesPublisher) -> [AnyCancellable] {
                state.bind(to: \.count) { model in
                    model.displayText = "Updated: \(model.count)"
                }
            }

            @AnyTokenBuilder<Any>
            static func applyAnyRules(to state: UIBinding<Self>) -> [Any] {
                // No external rules
            }
        }

        @ManagedState
        var model = ComplexModel()

        XCTAssertEqual(model.count, 0)
        XCTAssertTrue(model.isEven)
        XCTAssertEqual(model.displayText, "Count: 0")

        model.count = 5
        XCTAssertEqual(model.count, 5)
        XCTAssertFalse(model.isEven)
        XCTAssertEqual(model.displayText, "Count: 5")

        model.count = 6
        XCTAssertEqual(model.count, 6)
        XCTAssertTrue(model.isEven)
        XCTAssertEqual(model.displayText, "Count: 6")
    }

    func testManagedStateWithMultipleSubscribers() {
        @ManagedState
        var model = TestModel(number: 0, binding: 0)

        var subscriber1Values: [TestModel] = []
        var subscriber2Values: [TestModel] = []
        var subscriber3Values: [Int] = []

        let cancellable1 = $model.sink { subscriber1Values.append($0) }
        let cancellable2 = $model.sink { subscriber2Values.append($0) }
        let cancellable3 = $model.number.sink { subscriber3Values.append($0) }

        model.number = 1
        model.number = 2
        model.number = 3

        XCTAssertEqual(subscriber1Values.count, 4) // 0, 1, 2, 3
        XCTAssertEqual(subscriber2Values.count, 4) // 0, 1, 2, 3
        XCTAssertEqual(subscriber3Values.count, 4) // 0, 1, 2, 3

        XCTAssertEqual(subscriber1Values.last?.number, 3)
        XCTAssertEqual(subscriber2Values.last?.number, 3)
        XCTAssertEqual(subscriber3Values.last, 3)

        cancellable1.cancel()
        cancellable2.cancel()
        cancellable3.cancel()
    }

    func testManagedStateWithCancellation() {
        @ManagedState
        var model = TestModel(number: 0, binding: 0)

        var receivedValues: [TestModel] = []
        let cancellable = $model.sink { receivedValues.append($0) }

        model.number = 1
        model.number = 2

        XCTAssertEqual(receivedValues.count, 3) // 0, 1, 2

        // Cancel subscription
        cancellable.cancel()

        model.number = 3
        model.number = 4

        // Should only receive values before cancellation
        XCTAssertEqual(receivedValues.count, 3) // Still 0, 1, 2
    }

    func testManagedStateWithCombineOperators() {
        @ManagedState
        var model = TestModel(number: 0, binding: 0)

        var receivedValues: [Int] = []
        let expectation = XCTestExpectation(description: "Should receive filtered values")

        $model.number
            .filter { $0.new > 5 }
            .map { $0.new * 2 }
            .sink { value in
                receivedValues.append(value)
                if receivedValues.count == 2 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        model.number = 1 // Should be filtered out
        model.number = 6 // Should become 12
        model.number = 2 // Should be filtered out
        model.number = 8 // Should become 16

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedValues, [12, 16])
    }

    func testManagedStateWithKeyPathObservation() {
        @ManagedState
        var model = TestModel(number: 0, binding: 0)

        var numberValues: [Int] = []
        var bindingValues: [Int] = []
        var textValues: [String] = []

        $model.number.sink { numberValues.append($0) }.store(in: &cancellables)
        $model.binding.sink { bindingValues.append($0) }.store(in: &cancellables)
        $model.text.sink { textValues.append($0) }.store(in: &cancellables)

        model.number = 5
        model.number = 10
        model.number = 15

        XCTAssertEqual(numberValues, [0, 5, 10, 15])
        XCTAssertEqual(bindingValues, [0, 5, 10, 15]) // Should match number due to rules
        XCTAssertEqual(textValues, ["0", "5", "10", "15"])
    }

    func testManagedStateWithDirectPropertyAccess() {
        @ManagedState
        var model = TestModel(number: 0, binding: 0)

        // Test direct property access
        XCTAssertEqual(model.number, 0)
        XCTAssertEqual(model.binding, 0)
        XCTAssertEqual(model.text, "0")

        // Test direct property modification
        model.number = 42
        XCTAssertEqual(model.number, 42)
        XCTAssertEqual(model.binding, 42) // Should be updated by rules
        XCTAssertEqual(model.text, "42")

        // Test direct property modification of derived properties
        model.binding = 100
        XCTAssertEqual(model.binding, 100)
        // Note: number should remain 42 as binding doesn't affect number in our rules
    }

    func testManagedStateWithPublisherSubscription() {
        @ManagedState
        var model = TestModel(number: 0, binding: 0)

        var receivedValues: [TestModel] = []
        let expectation = XCTestExpectation(description: "Should receive values")

        $model
            .sink { value in
                receivedValues.append(value)
                if receivedValues.count == 3 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        model.number = 1
        model.number = 2

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedValues.count, 3) // 0, 1, 2
        XCTAssertEqual(receivedValues.last?.number, 2)
    }

    func testManagedStateWithDiffedValues() {
        @ManagedState
        var model = TestModel(number: 0, binding: 0)

        var receivedValues: [TestModel] = []
        let expectation = XCTestExpectation(description: "Should receive values")

        $model
            .sink { value in
                receivedValues.append(value)
                if receivedValues.count == 3 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        model.number = 1
        model.number = 2

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedValues.count, 3)

        // Check that we receive the correct values
        XCTAssertEqual(receivedValues[0].number, 0)
        XCTAssertEqual(receivedValues[1].number, 1)
        XCTAssertEqual(receivedValues[2].number, 2)
    }

    func testManagedStateWithConcurrentAccess() {
        @ManagedState
        var model = TestModel(number: 0, binding: 0)

        let expectation = XCTestExpectation(description: "Concurrent access")
        expectation.expectedFulfillmentCount = 10

        // Test concurrent access
        for i in 0..<10 {
            DispatchQueue.global().async { [_model] in
                _model.number = i
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 5.0)

        // Should have some final value (exact value depends on timing)
        XCTAssertTrue(model.number >= 0 && model.number < 10)
        XCTAssertEqual(model.binding, model.number) // Should match due to rules
    }

    func testManagedStateWithMemoryManagement() {
        // ManagedState is a struct, so we can't test weak references
        // Instead, test that it can be created and used
        @ManagedState
        var model = TestModel(number: 0, binding: 0)

        XCTAssertEqual(model.number, 0)
        XCTAssertEqual(model.binding, 0)

        model.number = 42
        XCTAssertEqual(model.number, 42)
        XCTAssertEqual(model.binding, 42) // Should be updated by rules
    }

    func testManagedStateWithNotificationCenter() {
        // Use subject pattern similar to the class property (line 6-7)
        @ManagedState
        var subject: NotificationTestModel = .init()

        subscribe()
        
        // Clear previous values and set up tracking for this test
        clearValues()
        var receivedNumbers: [Int] = []
        var receivedTexts: [String] = []
        
        // Subscribe to changes using subject (similar to class subscribe() method)
        $subject.number
            .sink { new in
                receivedNumbers.append(new)
            }
            .store(in: &cancellables)
        
        $subject.text
            .sink { new in
                receivedTexts.append(new)
            }
            .store(in: &cancellables)
        
        // Initial state
        XCTAssertEqual(subject.number, 0)
        XCTAssertEqual(subject.text, "0")
        XCTAssertEqual(subject.binding, 0)
        
        // Post notification which should trigger the subscription in applyAnyRules
        // and change number to 42, which will call applyRules
        NotificationCenter.default.post(name: NotificationTestModel.testNotificationName, object: nil)

        // Wait a bit for async operations
        let expectation = XCTestExpectation(description: "Notification processed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Verify that applyRules was called (text should be updated to "42")
        XCTAssertEqual(subject.number, 42, "Number should be updated from notification")
        XCTAssertEqual(subject.text, "42", "Text should be updated by applyRules")
        XCTAssertEqual(subject.binding, 42, "Binding should be updated by applyRules")
        
        // Verify that subscribers received updates
        XCTAssertTrue(receivedNumbers.contains(42), "Number subscriber should receive 42")
        XCTAssertTrue(receivedTexts.contains("42"), "Text subscriber should receive '42'")
    }
}

private struct NotificationTestModel: Hashable, BehavioralStateContract, CustomDebugStringConvertible {
    var number: Int = 0
    var binding: Int = 0
    var text: String = "initial"

    var debugDescription: String {
        return "<number: \(number), binding: \(binding), text: \(text)>"
    }

    init() {
    }

    mutating func applyRules() {
        text = "\(number)"
    }

    @SubscriptionBuilder
    static func applyBindingRules(to state: RulesPublisher) -> [AnyCancellable] {
        state.bindDiffed(to: \.number) { parent in
            parent.new.binding = parent.new.number
        }
    }

    static let testNotificationName = Notification.Name("TestModelNotification")

    @AnyTokenBuilder<Any>
    static func applyAnyRules(to state: UIBinding<Self>) -> [Any] {
            // Subscribe to test notification for ManagedStateTests
        NotificationCenter.default
            .publisher(for: testNotificationName)
            .sink { _ in
                // Change the value which will trigger applyRules
                state.wrappedValue.number = 42
            }
    }
}

extension NotificationTestModel: @unchecked Sendable {}
