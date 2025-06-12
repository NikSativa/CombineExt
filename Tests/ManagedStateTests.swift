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
        subject.number += 1
        subject.number += 1
        subject.number += 1
        subject.number += 1

        XCTAssertEqual(subject.number, 4)
        XCTAssertEqual(subject.text, "4")

        XCTAssertEqual(models, [
            .init(number: 0, binding: 0),
            .init(number: 1, binding: 1),
            .init(number: 2, binding: 2),
            .init(number: 3, binding: 3),
            .init(number: 4, binding: 4)
        ])
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
}
