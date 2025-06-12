import CombineExt
import Foundation
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
        _second = $subject.list.unsafe(1)

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

private extension UIStateTests {
    struct State: Equatable {
        var counter: Int = -1
        var toggle: Bool = false
        var list: [Int] = []
    }
}
