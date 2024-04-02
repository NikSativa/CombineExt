import Foundation
import NValueSubject
import XCTest

final class ValueSubjectTests: XCTestCase {
    private let subject: ValueSubject<State> = .init(wrappedValue: .init(counter: -1, toggle: false))
    private var observers: Set<AnyCancellable> = []
    private var rootStates: [State] = []

    override func setUp() {
        super.setUp()
        subject.sink { [unowned self] state in
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
        subject.wrappedValue.toggle.toggle()
        subject.wrappedValue.counter += 1
        subject.wrappedValue.counter += 1

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

        var newCounterStates: [Int] = []
        let newCounterSubject = subject.observe(keyPath: \.counter)
        newCounterSubject.sink { state in
            newCounterStates.append(state)
        }.store(in: &observers)
        expected.append(.init(counter: -1, toggle: false)) // initial
        XCTAssertEqual(newCounterSubject.wrappedValue, subject.wrappedValue.counter)

        subject.wrappedValue.toggle.toggle()
        expected.append(.init(counter: -1, toggle: true))
        subject.wrappedValue.counter += 1
        expected.append(.init(counter: 0, toggle: true))
        subject.wrappedValue.counter += 1
        expected.append(.init(counter: 1, toggle: true))

        newCounterSubject.wrappedValue = 5
        expected.append(.init(counter: 5, toggle: true))
        newCounterSubject.wrappedValue = 3
        expected.append(.init(counter: 3, toggle: true))

        var newSecondCounterStates: [Int] = []
        let newSecondCounterSubject = subject.observe(keyPath: \.counter)
        newCounterSubject.sink { state in
            newSecondCounterStates.append(state)
        }.store(in: &observers)
        XCTAssertEqual(newSecondCounterSubject.wrappedValue, subject.wrappedValue.counter)

        var newToggleStates: [Bool] = []
        let newToggleSubject = subject.observe(keyPath: \.toggle)
        newToggleSubject.sink { state in
            newToggleStates.append(state)
        }.store(in: &observers)
        XCTAssertEqual(newToggleSubject.wrappedValue, subject.wrappedValue.toggle)

        let dropFirstForNewObserver = expected.count - 1

        subject.wrappedValue.counter += 1
        expected.append(.init(counter: 4, toggle: true))
        subject.wrappedValue.counter -= 1
        expected.append(.init(counter: 3, toggle: true))
        subject.wrappedValue.counter -= 1
        expected.append(.init(counter: 2, toggle: true))
        subject.wrappedValue.toggle.toggle()
        expected.append(.init(counter: 2, toggle: false))

        newCounterSubject.wrappedValue += 1
        expected.append(.init(counter: 3, toggle: false))
        newCounterSubject.wrappedValue = 22
        expected.append(.init(counter: 22, toggle: false))

        newSecondCounterSubject.wrappedValue = 55
        expected.append(.init(counter: 55, toggle: false))
        newSecondCounterSubject.wrappedValue = -11
        expected.append(.init(counter: -11, toggle: false))

        newToggleSubject.wrappedValue.toggle()
        expected.append(.init(counter: -11, toggle: true))
        newSecondCounterSubject.wrappedValue = 1
        expected.append(.init(counter: 1, toggle: true))
        newToggleSubject.wrappedValue.toggle()
        expected.append(.init(counter: 1, toggle: false))

        XCTAssertEqual(rootStates, expected)

        let expectedCounterStates: [Int] = expected.map(\.counter)
        XCTAssertEqual(newCounterStates, expectedCounterStates)
        XCTAssertEqual(newCounterSubject.wrappedValue, subject.wrappedValue.counter)

        let expectedSecondCounterStates: [Int] = expected.dropFirst(dropFirstForNewObserver).map(\.counter)
        XCTAssertEqual(newSecondCounterStates, expectedSecondCounterStates)
        XCTAssertEqual(newSecondCounterSubject.wrappedValue, subject.wrappedValue.counter)

        let expectedBoolStates: [Bool] = expected.dropFirst(dropFirstForNewObserver).map(\.toggle)
        XCTAssertEqual(newToggleStates, expectedBoolStates)
        XCTAssertEqual(newToggleSubject.wrappedValue, subject.wrappedValue.toggle)
    }
}

// MARK: - ValueSubjectTests.State

private extension ValueSubjectTests {
    struct State: Equatable {
        var counter: Int
        var toggle: Bool
    }
}
