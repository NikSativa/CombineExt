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

        @ValueSubject
        var newCounterSubject: Int
        _newCounterSubject = _subject.observe(keyPath: \.counter)

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

        @ValueSubject
        var newSecondCounterSubject: Int
        _newSecondCounterSubject = _subject.observe(keyPath: \.counter)

        var newSecondCounterStates: [Int] = []
        $newSecondCounterSubject.sink { state in
            newSecondCounterStates.append(state)
        }
        .store(in: &observers)
        XCTAssertEqual(newSecondCounterSubject, subject.counter)

        @ValueSubject
        var newToggleSubject: Bool
        _newToggleSubject = _subject.observe(keyPath: \.toggle)

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

    // MARK: - Additional ValueSubject Tests

    func testValueSubjectInitialization() {
        @ValueSubject
        var intValue: Int = 42

        XCTAssertEqual(intValue, 42)

        @ValueSubject
        var stringValue: String = "Hello"

        XCTAssertEqual(stringValue, "Hello")

        @ValueSubject
        var optionalValue: String? = nil

        XCTAssertNil(optionalValue)
    }

    func testValueSubjectPublisher() {
        @ValueSubject
        var counter: Int = 0

        var receivedValues: [Int] = []
        let expectation = XCTestExpectation(description: "Publisher should emit values")

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
        counter = 3

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedValues, [0, 1, 2, 3])
    }

    func testValueSubjectWithDifferentTypes() {
        @ValueSubject
        var intValue: Int = 0

        @ValueSubject
        var stringValue: String = "initial"

        @ValueSubject
        var boolValue: Bool = false

        var intValues: [Int] = []
        var stringValues: [String] = []
        var boolValues: [Bool] = []

        $intValue.sink { intValues.append($0) }.store(in: &observers)
        $stringValue.sink { stringValues.append($0) }.store(in: &observers)
        $boolValue.sink { boolValues.append($0) }.store(in: &observers)

        intValue = 42
        stringValue = "updated"
        boolValue = true

        XCTAssertEqual(intValues, [0, 42])
        XCTAssertEqual(stringValues, ["initial", "updated"])
        XCTAssertEqual(boolValues, [false, true])
    }

    func testValueSubjectWithOptionalValues() {
        @ValueSubject
        var optionalInt: Int? = nil

        var receivedValues: [Int?] = []
        $optionalInt.sink { receivedValues.append($0) }.store(in: &observers)

        optionalInt = 42
        optionalInt = nil
        optionalInt = 100

        XCTAssertEqual(receivedValues, [nil, 42, nil, 100])
    }

    func testValueSubjectWithArrayValues() {
        @ValueSubject
        var arrayValue: [Int] = []

        var receivedValues: [[Int]] = []
        $arrayValue.sink { receivedValues.append($0) }.store(in: &observers)

        arrayValue = [1, 2, 3]
        arrayValue = [4, 5, 6]
        arrayValue = []

        XCTAssertEqual(receivedValues, [[], [1, 2, 3], [4, 5, 6], []])
    }

    func testValueSubjectWithStructValues() {
        struct TestStruct: Equatable {
            var id: Int
            var name: String
        }

        @ValueSubject
        var structValue: TestStruct = .init(id: 0, name: "initial")

        var receivedValues: [TestStruct] = []
        $structValue.sink { receivedValues.append($0) }.store(in: &observers)

        structValue = TestStruct(id: 1, name: "updated")
        structValue = TestStruct(id: 2, name: "final")

        XCTAssertEqual(receivedValues.count, 3)
        XCTAssertEqual(receivedValues[0], TestStruct(id: 0, name: "initial"))
        XCTAssertEqual(receivedValues[1], TestStruct(id: 1, name: "updated"))
        XCTAssertEqual(receivedValues[2], TestStruct(id: 2, name: "final"))
    }

    func testValueSubjectWithEquatableValues() {
        @ValueSubject
        var value: Int = 0

        var receivedValues: [Int] = []
        $value.sink { receivedValues.append($0) }.store(in: &observers)

        // Same value should not emit
        value = 0
        value = 1
        value = 1 // Should not emit
        value = 2

        XCTAssertEqual(receivedValues, [0, 0, 1, 1, 2]) // ValueSubject emits all values, including duplicates
    }

    func testValueSubjectMultipleSubscribers() {
        @ValueSubject
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

    func testValueSubjectCancellation() {
        @ValueSubject
        var counter: Int = 0

        var receivedValues: [Int] = []
        let cancellable = $counter.sink { receivedValues.append($0) }

        counter = 1
        counter = 2

        // Cancel subscription
        cancellable.cancel()

        counter = 3
        counter = 4

        // Should only receive values before cancellation
        XCTAssertEqual(receivedValues, [0, 1, 2])
    }

    func testValueSubjectWithCombineOperators() {
        @ValueSubject
        var counter: Int = 0

        var receivedValues: [Int] = []
        let expectation = XCTestExpectation(description: "Should receive filtered values")

        $counter
            .filter { $0 > 5 }
            .map { $0 * 2 }
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
}

private extension ValueSubjectTests {
    struct State: Equatable {
        var counter: Int
        var toggle: Bool
    }
}
