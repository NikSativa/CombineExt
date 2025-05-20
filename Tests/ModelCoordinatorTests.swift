import Combine
import CombineExt
import XCTest

final class ManagedStateTests: XCTestCase {
    @ManagedState
    private var subject: TestModel = .init()
    private var cancellables: Set<AnyCancellable>!
    private var models: [TestModel] = []
    private var numbers: [Int] = []
    private var texts: [String] = []

    override func setUp() {
        super.setUp()
        cancellables = []
        models = []
        numbers = []
        texts = []
    }

    override func tearDown() {
        super.tearDown()
        cancellables = nil
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
    func testSendActions() async throws {
        subscribe()

        // initial
        XCTAssertEqual(models, [.init(text: "0")])
        XCTAssertEqual(numbers, [0])
        XCTAssertEqual(texts, ["0"])

        // actions
        $subject.send(.increment)
        $subject.send(.increment)
        $subject.send(.increment)
        $subject.send(.increment)

        // not updated yet
        XCTAssertEqual(subject.number, 0)
        XCTAssertEqual(subject.text, "0")

        XCTAssertEqual(models, [.init(text: "0")])
        XCTAssertEqual(numbers, [0])
        XCTAssertEqual(texts, ["0"])

        await awaitPropagation()

        // updated
        XCTAssertEqual(models, [
            .init(number: 0, text: "0"),
            .init(number: 4, text: "4")
        ])
        XCTAssertEqual(numbers, [0, 4])
        XCTAssertEqual(texts, ["0", "4"])

        XCTAssertEqual(subject.number, 4)
        XCTAssertEqual(subject.text, "4")
    }

    @MainActor
    func testSink() async throws {
        subscribe()

        // initial
        XCTAssertEqual(models, [.init(text: "0")])
        XCTAssertEqual(numbers, [0])
        XCTAssertEqual(texts, ["0"])

        await awaitPropagation()

        // nothing changed
        XCTAssertEqual(models, [.init(text: "0")])
        XCTAssertEqual(numbers, [0])
        XCTAssertEqual(texts, ["0"])

        subject.number = 1

        // not updated yet
        XCTAssertEqual(models, [.init(text: "0"), .init(number: 1, text: "0")])
        XCTAssertEqual(numbers, [0, 1])
        XCTAssertEqual(texts, ["0", "0"])

        await awaitPropagation()

        // updated
        XCTAssertEqual(models, [
            .init(number: 0, text: "0"),
            .init(number: 1, text: "0"),
            .init(number: 1, text: "1")
        ])
        XCTAssertEqual(numbers, [0, 1, 1])
        XCTAssertEqual(texts, ["0", "0", "1"])

        subject.number += 1
        subject.number += 1
        subject.number += 1

        // not updated yet
        XCTAssertEqual(models, [
            .init(number: 0, text: "0"),
            .init(number: 1, text: "0"),
            .init(number: 1, text: "1"),
            .init(number: 2, text: "1"),
            .init(number: 3, text: "1"),
            .init(number: 4, text: "1")
        ])
        XCTAssertEqual(numbers, [0, 1, 1, 2, 3, 4])
        XCTAssertEqual(texts, ["0", "0", "1", "1", "1", "1"])

        await awaitPropagation()

        // updated
        XCTAssertEqual(models, [
            .init(number: 0, text: "0"),
            .init(number: 1, text: "0"),
            .init(number: 1, text: "1"),
            .init(number: 2, text: "1"),
            .init(number: 3, text: "1"),
            .init(number: 4, text: "1"),
            .init(number: 4, text: "4")
        ])
        XCTAssertEqual(numbers, [0, 1, 1, 2, 3, 4, 4])
        XCTAssertEqual(texts, ["0", "0", "1", "1", "1", "1", "4"])

        XCTAssertEqual(subject.number, 4)
        XCTAssertEqual(subject.text, "4")
    }

    private func subscribe() {
        $subject.observe(\.self).sink { new in
            self.models.append(new)
        }.store(in: &cancellables)

        $subject.number.sink { new in
            self.numbers.append(new)
        }.store(in: &cancellables)

        $subject.text.sink { new in
            self.texts.append(new)
        }.store(in: &cancellables)
    }

    @MainActor
    private func awaitPropagation() async {
        try? await Task.sleep(nanoseconds: 100_000)
    }
}

private struct TestModel: BehavioralStateContract, CustomDebugStringConvertible {
    enum Action {
        case increment
        case value(Int)
    }

    var number: Int = 0
    var text: String = "initial"

    var debugDescription: String {
        return "<number: \(number), text: \(text)>"
    }

    mutating func apply(_ action: Action) {
        switch action {
        case .increment:
            number += 1
        case .value(let new):
            number = new
        }
    }

    mutating func postActionsProcessing() {
        text = "\(number)"
    }

    @SubscriptionBuilder
    static func applyBindingRules(for state: UIBinding<Self>, to receiver: EventSubject<Action>) -> [AnyCancellable] {}

    @NotificationBuilder
    static func applyNotificationRules(to coordinator: ManagedState<Self>) -> [NotificationToken] {}
}
