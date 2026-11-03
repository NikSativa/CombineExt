import Combine
import CombineExt
import XCTest

final class ManagedStateTests: XCTestCase {
    @ManagedState
    private var subject: TestModel = .init()
    private var cancellables: Set<AnyCancellable>!
    private var models: [TestModel] = []
    private var numbers: [Int] = []
    private var binding: [Int] = []
    private var texts: [String] = []

    override func setUp() {
        super.setUp()
        cancellables = []
    }

    override func tearDown() {
        super.tearDown()
        cancellables = nil
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

    func testClosureCapturesPropertyWrapperStorage() {
        let readNumber: () -> Int = { [_subject] in
            return _subject.number
        }

        subject.number = 7

        XCTAssertEqual(readNumber(), 7)
    }

    func testEditable() {
        subscribe()

        XCTAssertEqual(models, [.init(text: "0")])
        XCTAssertEqual(numbers, [0])
        XCTAssertEqual(binding, [0])
        XCTAssertEqual(texts, ["0"])

        DispatchQueue.concurrentPerform(iterations: 4) { [_subject] idx in
            _subject.number = idx + 1
        }

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

    func testWithLock() {
        subscribe()

        XCTAssertEqual(models, [.init(text: "0")])
        XCTAssertEqual(numbers, [0])
        XCTAssertEqual(binding, [0])
        XCTAssertEqual(texts, ["0"])

        DispatchQueue.concurrentPerform(iterations: 4) { [_subject] _ in
            _subject.withLock { value in
                value.number += 1
            }
        }

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

        _subject.withLock { value in
            value.number = 10
        }

        XCTAssertEqual(subject.number, 10)
        XCTAssertEqual(subject.binding, 10)
        XCTAssertEqual(subject.text, "10")

        XCTAssertEqual(numbers, [0, 10])
        XCTAssertEqual(binding, [0, 10])
        XCTAssertEqual(texts, ["0", "10"])
    }

    func testWithLockNoChange() {
        subscribe()

        let initialCount = numbers.count

        _subject.withLock { _ in
        }

        XCTAssertEqual(numbers.count, initialCount)
        XCTAssertEqual(subject.number, 0)
        XCTAssertEqual(subject.text, "0")
    }

    func testInitialization() {
        XCTAssertEqual(subject.number, 0)
        XCTAssertEqual(subject.text, "0")
        XCTAssertEqual(models, [])
        XCTAssertEqual(numbers, [])
        XCTAssertEqual(binding, [])
        XCTAssertEqual(texts, [])
    }

    func testSink() {
        subscribe()

        XCTAssertEqual(models, [.init(text: "0")])
        XCTAssertEqual(numbers, [0])
        XCTAssertEqual(binding, [0])
        XCTAssertEqual(texts, ["0"])

        subject.number = 1

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
        CounterModel.counterFunc = 0
        CounterModel.counterBind = 0

        @ManagedState
        var state: CounterModel = .init()
        XCTAssertEqual(state.valueFunc, 0)
        XCTAssertEqual(state.valueBind, 0)
        XCTAssertEqual(CounterModel.counterFunc, 1)
        XCTAssertEqual(CounterModel.counterBind, 1)

        state.value += 1
        XCTAssertEqual(state.valueFunc, 2)
        XCTAssertEqual(state.valueBind, 3)
        XCTAssertEqual(CounterModel.counterFunc, 3)
        XCTAssertEqual(CounterModel.counterBind, 2)

        state.value += 1
        XCTAssertEqual(state.valueFunc, 4)
        XCTAssertEqual(state.valueBind, 6)
        XCTAssertEqual(CounterModel.counterFunc, 5)
        XCTAssertEqual(CounterModel.counterBind, 3)

        state.value += 1
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

    nonisolated(unsafe) static var counterFunc: Int = 0
    nonisolated(unsafe) static var counterBind: Int = 0

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

    func testManagedStateWithDifferentLockTypes() {
        @ManagedState(lock: .absent)
        var model1 = TestModel(number: 0, binding: 0)

        XCTAssertEqual(model1.number, 0)
        XCTAssertEqual(model1.binding, 0)

        model1.number = 10
        XCTAssertEqual(model1.number, 10)
        XCTAssertEqual(model1.binding, 10)

        @ManagedState(lock: .synced)
        var model2 = TestModel(number: 0, binding: 0)

        XCTAssertEqual(model2.number, 0)
        XCTAssertEqual(model2.binding, 0)

        model2.number = 20
        XCTAssertEqual(model2.number, 20)
        XCTAssertEqual(model2.binding, 20)

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

            mutating func applyRules() {
                isEven = count % 2 == 0
            }

            @SubscriptionBuilder
            static func applyBindingRules(to state: RulesPublisher) -> [AnyCancellable] {
                state.bind(to: \.count) { model in
                    model.displayText = "Count: \(model.count)"
                }
            }

            @AnyTokenBuilder<Any>
            static func applyAnyRules(to state: UIBinding<Self>) -> [Any] {}
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

        XCTAssertEqual(subscriber1Values.count, 4)
        XCTAssertEqual(subscriber2Values.count, 4)
        XCTAssertEqual(subscriber3Values.count, 4)

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

        XCTAssertEqual(receivedValues.count, 3)

        cancellable.cancel()

        model.number = 3
        model.number = 4

        XCTAssertEqual(receivedValues.count, 3)
    }

    func testManagedStateWithCombineOperators() {
        @ManagedState
        var model = TestModel(number: 0, binding: 0)

        var receivedValues: [Int] = []

        $model.number
            .filter { $0.new > 5 }
            .map { $0.new * 2 }
            .sink { value in
                receivedValues.append(value)
            }
            .store(in: &cancellables)

        model.number = 1
        model.number = 6
        model.number = 2
        model.number = 8

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
        XCTAssertEqual(bindingValues, [0, 5, 10, 15])
        XCTAssertEqual(textValues, ["0", "5", "10", "15"])
    }

    func testManagedStateWithDirectPropertyAccess() {
        @ManagedState
        var model = TestModel(number: 0, binding: 0)

        XCTAssertEqual(model.number, 0)
        XCTAssertEqual(model.binding, 0)
        XCTAssertEqual(model.text, "0")

        model.number = 42
        XCTAssertEqual(model.number, 42)
        XCTAssertEqual(model.binding, 42)
        XCTAssertEqual(model.text, "42")

        model.binding = 100
        XCTAssertEqual(model.binding, 100)
        XCTAssertEqual(model.number, 42)
        XCTAssertEqual(model.text, "42")
    }

    func testManagedStateWithDiffedValues() {
        @ManagedState
        var model = TestModel(number: 0, binding: 0)

        var oldNumbers: [Int?] = []
        var newNumbers: [Int] = []

        $model.diffedPublisher
            .sink { diff in
                oldNumbers.append(diff.old?.number)
                newNumbers.append(diff.new.number)
            }
            .store(in: &cancellables)

        model.number = 1
        model.number = 2

        XCTAssertEqual(oldNumbers, [0, 0, 1])
        XCTAssertEqual(newNumbers, [0, 1, 2])
    }

    func testManagedStateWithConcurrentAccess() {
        @ManagedState
        var model = TestModel(number: 0, binding: 0)

        var publishedValues: [TestModel] = []
        $model.publisher
            .sink { value in
                publishedValues.append(value)
            }
            .store(in: &cancellables)

        DispatchQueue.concurrentPerform(iterations: 10) { [_model] i in
            _model.number = i
        }

        XCTAssertTrue(Set(publishedValues.map(\.number)).isSuperset(of: 1...9))
        XCTAssertEqual(publishedValues.last, model)
        XCTAssertTrue(publishedValues.allSatisfy { $0.binding == $0.number })
        XCTAssertEqual(model.binding, model.number)
    }

    func testManagedStateIsReleasedWhenAnyRuleKeepsBinding() {
        weak var weakModel: ManagedState<NotificationTestModel>?

        do {
            let model = ManagedState(wrappedValue: NotificationTestModel())
            weakModel = model
            model.number = 1
        }

        XCTAssertNil(weakModel)
    }

    func testDisabledCyclicDependencyWarningDoesNotStopDivergentRules() {
        let warning = ManagedStateCyclicDependencyWarning
        let maxDepth = ManagedStateCyclicDependencyMaxDepth
        defer {
            ManagedStateCyclicDependencyWarning = warning
            ManagedStateCyclicDependencyMaxDepth = maxDepth
        }
        ManagedStateCyclicDependencyWarning = false
        ManagedStateCyclicDependencyMaxDepth = 100

        let model = ManagedState(wrappedValue: DivergentModel())

        XCTAssertEqual(model.passes, 100)
    }

    func testDivergentRulesStopAfterMaxDepthPasses() {
        let warning = ManagedStateCyclicDependencyWarning
        let maxDepth = ManagedStateCyclicDependencyMaxDepth
        defer {
            ManagedStateCyclicDependencyWarning = warning
            ManagedStateCyclicDependencyMaxDepth = maxDepth
        }
        ManagedStateCyclicDependencyWarning = false
        ManagedStateCyclicDependencyMaxDepth = 5

        let model = ManagedState(wrappedValue: DivergentModel())
        XCTAssertEqual(model.passes, 5)

        model.trigger = 1
        XCTAssertEqual(model.passes, 10)
    }

    func testConcurrentFirstAccessToPublisherIsSafe() {
        let model = ManagedState(wrappedValue: TestModel(number: 0, binding: 0))

        DispatchQueue.concurrentPerform(iterations: 100) { _ in
            _ = model.publisher
        }

        var numbers: [Int] = []
        let cancellable = model.publisher.sink { value in
            numbers.append(value.number)
        }
        model.number = 1

        XCTAssertEqual(numbers, [0, 1])
        cancellable.cancel()
    }

    func testEqualityAndHashFollowManagedValue() {
        let first = ManagedState(wrappedValue: TestModel(number: 1, binding: 1))
        let second = ManagedState(wrappedValue: TestModel(number: 1, binding: 1))
        let different = ManagedState(wrappedValue: TestModel(number: 2, binding: 2))

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.hashValue, second.hashValue)
        XCTAssertNotEqual(first, different)

        second.number = 2

        XCTAssertEqual(second, different)
        XCTAssertEqual(second.hashValue, different.hashValue)
    }

    func testKeyPathBindingRuleRunsOnlyWhenItsFieldChanges() {
        TrimmedTitleModel.titleRuleCalls = 0
        let model = ManagedState(wrappedValue: TrimmedTitleModel())
        let callsAfterInit = TrimmedTitleModel.titleRuleCalls

        model.title = " Hello "
        XCTAssertEqual(model.title, "Hello")
        XCTAssertEqual(TrimmedTitleModel.titleRuleCalls, callsAfterInit + 2)

        model.amount = 1
        XCTAssertEqual(TrimmedTitleModel.titleRuleCalls, callsAfterInit + 2)
    }

    func testManagedStateWithNotificationCenter() {
        @ManagedState
        var subject: NotificationTestModel = .init()

        var receivedNumbers: [Int] = []
        var receivedTexts: [String] = []

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

        XCTAssertEqual(subject.number, 0)
        XCTAssertEqual(subject.text, "0")
        XCTAssertEqual(subject.binding, 0)

        NotificationCenter.default.post(name: NotificationTestModel.testNotificationName, object: nil)

        XCTAssertEqual(subject.number, 42, "Number should be updated from notification")
        XCTAssertEqual(subject.text, "42", "Text should be updated by applyRules")
        XCTAssertEqual(subject.binding, 42, "Binding should be updated by applyRules")

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
        NotificationCenter.default
            .publisher(for: testNotificationName)
            .sink { _ in
                state.wrappedValue.number = 42
            }
    }
}

extension NotificationTestModel: @unchecked Sendable {}

private struct DivergentModel: BehavioralStateContract {
    var trigger: Int = 0
    var passes: Int = 0

    mutating func applyRules() {
        passes += 1
    }

    @SubscriptionBuilder
    static func applyBindingRules(to state: RulesPublisher) -> [AnyCancellable] {}

    @AnyTokenBuilder<Any>
    static func applyAnyRules(to state: UIBinding<Self>) -> [Any] {}
}

private struct TrimmedTitleModel: BehavioralStateContract {
    var title: String = ""
    var amount: Int = 0

    nonisolated(unsafe) static var titleRuleCalls: Int = 0

    mutating func applyRules() {}

    @SubscriptionBuilder
    static func applyBindingRules(to state: RulesPublisher) -> [AnyCancellable] {
        state.bind(to: \.title) { (title: inout String) in
            titleRuleCalls += 1
            title = title.trimmingCharacters(in: .whitespaces)
        }
    }

    @AnyTokenBuilder<Any>
    static func applyAnyRules(to state: UIBinding<Self>) -> [Any] {}
}
