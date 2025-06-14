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

    @MainActor
    func testClosureCapturing() {
        let some: () -> Void = { [_subject] in
            print("ignore me. \(_subject.number)")
        }
        some()
    }

    @MainActor
    func testEditable() async throws {
        subscribe()

        // initial
        XCTAssertEqual(models, [.init(text: "0")])
        XCTAssertEqual(numbers, [0])
        XCTAssertEqual(binding, [0])
        XCTAssertEqual(texts, ["0"])

        // actions
        var exps: [XCTestExpectation] = []
        for _ in 0..<4 {
            let exp = expectation(description: "incrementer")
            exps.append(exp)
            DispatchQueue.global().async { [_subject] in
                _subject.number += 1
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

    @MainActor
    func testInitialization() {
        XCTAssertEqual(subject.number, 0)
        XCTAssertEqual(subject.text, "0")
        XCTAssertEqual(models, [])
        XCTAssertEqual(numbers, [])
        XCTAssertEqual(texts, [])
    }

    @MainActor
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
        state.bindDiffed(to: \.value) { parent in
            counterBind += 1
            parent.new.valueBind = parent.new.value * 3
        }
    }

    @AnyTokenBuilder<Any>
    static func applyAnyRules(to state: UIBinding<Self>) -> [Any] {}
}

@propertyWrapper
private struct AlwaysEqual<Value: Equatable>: Equatable {
    var wrappedValue: Value

    init(wrappedValue: Value) {
        self.wrappedValue = wrappedValue
    }

    static func ==(lhs: Self, rhs: Self) -> Bool {
        return true
    }
}
