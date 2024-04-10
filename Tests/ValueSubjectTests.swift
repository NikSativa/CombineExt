import CombineExt
import Foundation
import XCTest

final class ValueSubjectTests: XCTestCase {
    @ValueSubject
    private var subject: State = .init(counter: -1, toggle: false)
    private var observers: Set<AnyCancellable> = []
    private var rootStates: [State] = []

    override func setUp() {
        super.setUp()
        $subject.sink { [unowned self] state in
            rootStates.append(state)
        }.store(in: &observers)
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

        @ValueSubject
        var newCounterSubject: Int
        _newCounterSubject = _subject.observe(keyPath: \.counter)

        var newCounterStates: [Int] = []
        $newCounterSubject.sink { state in
            newCounterStates.append(state)
        }.store(in: &observers)
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

        @ValueSubject
        var newSecondCounterSubject: Int
        _newSecondCounterSubject = _subject.observe(keyPath: \.counter)

        var newSecondCounterStates: [Int] = []
        $newSecondCounterSubject.sink { state in
            newSecondCounterStates.append(state)
        }.store(in: &observers)
        XCTAssertEqual(newSecondCounterSubject, subject.counter)

        @ValueSubject
        var newToggleSubject: Bool
        _newToggleSubject = _subject.observe(keyPath: \.toggle)

        var newToggleStates: [Bool] = []
        $newToggleSubject.sink { state in
            newToggleStates.append(state)
        }.store(in: &observers)
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
}

// MARK: - ValueSubjectTests.State

private extension ValueSubjectTests {
    struct State: Equatable {
        var counter: Int
        var toggle: Bool
    }
}
