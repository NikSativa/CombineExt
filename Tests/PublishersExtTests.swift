import Combine
import CombineExt
import Foundation
import XCTest

/// Helper structs for tuple testing
struct TestTuple5: Equatable {
    let string: String
    let int: Int
    let double: Double
    let bool: Bool
    let character: Character
}

struct TestTuple6: Equatable {
    let string: String
    let int: Int
    let double: Double
    let bool: Bool
    let character: Character
    let float: Float
}

final class PublishersExtTests: XCTestCase {
    private var cancellables: Set<AnyCancellable> = []
    func testFilterNils() {
        let subject = CurrentValueSubject<String?, Never>(nil)

        var receivedValues: [String] = []
        let cancellable = subject.filterNils().sink { value in
            receivedValues.append(value)
        }

        subject.send("Hello")
        subject.send(nil)
        subject.send("World")

        XCTAssertEqual(receivedValues, ["Hello", "World"])

        cancellable.cancel()
    }

    func testMapVoid() {
        let subject = CurrentValueSubject<String, Never>("Hello")

        var callCount = 0
        let cancellable = subject.mapVoid().sink {
            callCount += 1
        }

        subject.send("World")
        subject.send("Swift")

        XCTAssertEqual(callCount, 3) // Initial + 2 updates

        cancellable.cancel()
    }

    func testCombineLatest5() {
        let subject1 = PassthroughSubject<String, Never>()
        let subject2 = PassthroughSubject<Int, Never>()
        let subject3 = PassthroughSubject<Double, Never>()
        let subject4 = PassthroughSubject<Bool, Never>()
        let subject5 = PassthroughSubject<Character, Never>()

        var receivedValues: [TestTuple5] = []
        let cancellable = Publishers.CombineLatest5(subject1, subject2, subject3, subject4, subject5)
            .map { TestTuple5(string: $0, int: $1, double: $2, bool: $3, character: $4) }
            .sink { value in
                receivedValues.append(value)
            }

        // Send initial values
        subject1.send("A")
        subject2.send(1)
        subject3.send(1.0)
        subject4.send(true)
        subject5.send("X")

        // Send updates
        subject1.send("B")
        subject2.send(2)

        XCTAssertEqual(receivedValues.count, 3) // Initial + 2 updates
        XCTAssertEqual(receivedValues[0], TestTuple5(string: "A", int: 1, double: 1.0, bool: true, character: Character("X")))
        XCTAssertEqual(receivedValues[1], TestTuple5(string: "B", int: 1, double: 1.0, bool: true, character: Character("X")))
        XCTAssertEqual(receivedValues[2], TestTuple5(string: "B", int: 2, double: 1.0, bool: true, character: Character("X")))

        cancellable.cancel()
    }

    func testCombineLatest6() {
        let subject1 = PassthroughSubject<String, Never>()
        let subject2 = PassthroughSubject<Int, Never>()
        let subject3 = PassthroughSubject<Double, Never>()
        let subject4 = PassthroughSubject<Bool, Never>()
        let subject5 = PassthroughSubject<Character, Never>()
        let subject6 = PassthroughSubject<Float, Never>()

        var receivedValues: [TestTuple6] = []
        let cancellable = Publishers.CombineLatest6(subject1, subject2, subject3, subject4, subject5, subject6)
            .map { TestTuple6(string: $0, int: $1, double: $2, bool: $3, character: $4, float: $5) }
            .sink { value in
                receivedValues.append(value)
            }

        // Send initial values
        subject1.send("A")
        subject2.send(1)
        subject3.send(1.0)
        subject4.send(true)
        subject5.send("X")
        subject6.send(1.5)

        // Send updates
        subject1.send("B")
        subject2.send(2)

        XCTAssertEqual(receivedValues.count, 3) // Initial + 2 updates
        XCTAssertEqual(receivedValues[0], TestTuple6(string: "A", int: 1, double: 1.0, bool: true, character: Character("X"), float: 1.5))
        XCTAssertEqual(receivedValues[1], TestTuple6(string: "B", int: 1, double: 1.0, bool: true, character: Character("X"), float: 1.5))
        XCTAssertEqual(receivedValues[2], TestTuple6(string: "B", int: 2, double: 1.0, bool: true, character: Character("X"), float: 1.5))

        cancellable.cancel()
    }

    func testZip5() {
        let subject1 = PassthroughSubject<String, Never>()
        let subject2 = PassthroughSubject<Int, Never>()
        let subject3 = PassthroughSubject<Double, Never>()
        let subject4 = PassthroughSubject<Bool, Never>()
        let subject5 = PassthroughSubject<Character, Never>()

        var receivedValues: [TestTuple5] = []
        let cancellable = Publishers.Zip5(subject1, subject2, subject3, subject4, subject5)
            .map { TestTuple5(string: $0, int: $1, double: $2, bool: $3, character: $4) }
            .sink { value in
                receivedValues.append(value)
            }

        // Send values in order
        subject1.send("A")
        subject2.send(1)
        subject3.send(1.0)
        subject4.send(true)
        subject5.send("X")

        // Send second set
        subject1.send("B")
        subject2.send(2)
        subject3.send(2.0)
        subject4.send(false)
        subject5.send("Y")

        XCTAssertEqual(receivedValues.count, 2)
        XCTAssertEqual(receivedValues[0], TestTuple5(string: "A", int: 1, double: 1.0, bool: true, character: Character("X")))
        XCTAssertEqual(receivedValues[1], TestTuple5(string: "B", int: 2, double: 2.0, bool: false, character: Character("Y")))

        cancellable.cancel()
    }

    func testZip6() {
        let subject1 = PassthroughSubject<String, Never>()
        let subject2 = PassthroughSubject<Int, Never>()
        let subject3 = PassthroughSubject<Double, Never>()
        let subject4 = PassthroughSubject<Bool, Never>()
        let subject5 = PassthroughSubject<Character, Never>()
        let subject6 = PassthroughSubject<Float, Never>()

        var receivedValues: [TestTuple6] = []
        let cancellable = Publishers.Zip6(subject1, subject2, subject3, subject4, subject5, subject6)
            .map { TestTuple6(string: $0, int: $1, double: $2, bool: $3, character: $4, float: $5) }
            .sink { value in
                receivedValues.append(value)
            }

        // Send values in order
        subject1.send("A")
        subject2.send(1)
        subject3.send(1.0)
        subject4.send(true)
        subject5.send("X")
        subject6.send(1.5)

        // Send second set
        subject1.send("B")
        subject2.send(2)
        subject3.send(2.0)
        subject4.send(false)
        subject5.send("Y")
        subject6.send(2.5)

        XCTAssertEqual(receivedValues.count, 2)
        XCTAssertEqual(receivedValues[0], TestTuple6(string: "A", int: 1, double: 1.0, bool: true, character: Character("X"), float: 1.5))
        XCTAssertEqual(receivedValues[1], TestTuple6(string: "B", int: 2, double: 2.0, bool: false, character: Character("Y"), float: 2.5))

        cancellable.cancel()
    }

    func testCombineLatest5WithDifferentTypes() {
        let stringSubject = PassthroughSubject<String, Never>()
        let intSubject = PassthroughSubject<Int, Never>()
        let doubleSubject = PassthroughSubject<Double, Never>()
        let boolSubject = PassthroughSubject<Bool, Never>()
        let charSubject = PassthroughSubject<Character, Never>()

        var receivedValues: [TestTuple5] = []
        let cancellable = Publishers.CombineLatest5(stringSubject, intSubject, doubleSubject, boolSubject, charSubject)
            .map { TestTuple5(string: $0, int: $1, double: $2, bool: $3, character: $4) }
            .sink { value in
                receivedValues.append(value)
            }

        // Send values
        stringSubject.send("Hello")
        intSubject.send(42)
        doubleSubject.send(3.14)
        boolSubject.send(true)
        charSubject.send("A")

        XCTAssertEqual(receivedValues.count, 1)
        XCTAssertEqual(receivedValues[0], TestTuple5(string: "Hello", int: 42, double: 3.14, bool: true, character: Character("A")))

        cancellable.cancel()
    }

    func testZip5WithCompletion() {
        let subject1 = PassthroughSubject<String, Never>()
        let subject2 = PassthroughSubject<Int, Never>()
        let subject3 = PassthroughSubject<Double, Never>()
        let subject4 = PassthroughSubject<Bool, Never>()
        let subject5 = PassthroughSubject<Character, Never>()

        var receivedValues: [TestTuple5] = []
        var completionReceived = false
        let cancellable = Publishers.Zip5(subject1, subject2, subject3, subject4, subject5)
            .map { TestTuple5(string: $0, int: $1, double: $2, bool: $3, character: $4) }
            .sink(receiveCompletion: { _ in completionReceived = true },
                  receiveValue: { value in receivedValues.append(value) })

        // Send some values
        subject1.send("A")
        subject2.send(1)
        subject3.send(1.0)
        subject4.send(true)
        subject5.send("X")

        // Complete one subject
        subject1.send(completion: .finished)

        // Send more values (should not be received)
        subject2.send(2)
        subject3.send(2.0)
        subject4.send(false)
        subject5.send("Y")

        XCTAssertEqual(receivedValues.count, 1)
        XCTAssertEqual(receivedValues[0], TestTuple5(string: "A", int: 1, double: 1.0, bool: true, character: Character("X")))
        XCTAssertTrue(completionReceived)

        cancellable.cancel()
    }

    func testCombineLatest5WithFailure() {
        enum TestError: Error {
            case test
        }

        let subject1 = PassthroughSubject<String, TestError>()
        let subject2 = PassthroughSubject<Int, TestError>()
        let subject3 = PassthroughSubject<Double, TestError>()
        let subject4 = PassthroughSubject<Bool, TestError>()
        let subject5 = PassthroughSubject<Character, TestError>()

        var receivedValues: [(String, Int, Double, Bool, Character)] = []
        var errorReceived: Error?
        let cancellable = Publishers.CombineLatest5(subject1, subject2, subject3, subject4, subject5)
            .sink(receiveCompletion: { completion in
                      if case .failure(let error) = completion {
                          errorReceived = error
                      }
                  },
                  receiveValue: { value in receivedValues.append(value) })

        // Send initial values
        subject1.send("A")
        subject2.send(1)
        subject3.send(1.0)
        subject4.send(true)
        subject5.send("X")

        // Send error
        subject1.send(completion: .failure(.test))

        XCTAssertEqual(receivedValues.count, 1)
        let expected = ("A", 1, 1.0, true, Character("X"))
        XCTAssertEqual(receivedValues[0].0, expected.0)
        XCTAssertEqual(receivedValues[0].1, expected.1)
        XCTAssertEqual(receivedValues[0].2, expected.2)
        XCTAssertEqual(receivedValues[0].3, expected.3)
        XCTAssertEqual(receivedValues[0].4, expected.4)
        XCTAssertNotNil(errorReceived)

        cancellable.cancel()
    }

    // MARK: - Additional PublishersExt Tests

    func testFilterNilsWithEmptyStream() {
        let subject = PassthroughSubject<String?, Never>()
        var receivedValues: [String] = []

        subject
            .filterNils()
            .sink { receivedValues.append($0) }
            .store(in: &cancellables)

        subject.send(nil)
        subject.send(nil)
        subject.send(completion: .finished)

        XCTAssertEqual(receivedValues, [])
    }

    func testFilterNilsWithDifferentTypes() {
        let subject = PassthroughSubject<Int?, Never>()
        var receivedValues: [Int] = []

        subject
            .filterNils()
            .sink { receivedValues.append($0) }
            .store(in: &cancellables)

        subject.send(1)
        subject.send(nil)
        subject.send(2)
        subject.send(nil)
        subject.send(3)

        XCTAssertEqual(receivedValues, [1, 2, 3])
    }

    func testMapVoidWithDifferentTypes() {
        let subject = PassthroughSubject<Int, Never>()
        var receivedCount = 0

        subject
            .mapVoid()
            .sink { receivedCount += 1 }
            .store(in: &cancellables)

        subject.send(1)
        subject.send(2)
        subject.send(3)

        XCTAssertEqual(receivedCount, 3)
    }

    func testMapVoidWithStringValues() {
        let subject = PassthroughSubject<String, Never>()
        var receivedCount = 0

        subject
            .mapVoid()
            .sink { receivedCount += 1 }
            .store(in: &cancellables)

        subject.send("Hello")
        subject.send("World")
        subject.send("Test")

        XCTAssertEqual(receivedCount, 3)
    }

    func testMapVoidWithCompletion() {
        let subject = PassthroughSubject<Int, Never>()
        var receivedCount = 0
        var completed = false

        subject
            .mapVoid()
            .sink(receiveCompletion: { _ in completed = true },
                  receiveValue: { receivedCount += 1 })
            .store(in: &cancellables)

        subject.send(1)
        subject.send(2)
        subject.send(completion: .finished)

        XCTAssertEqual(receivedCount, 2)
        XCTAssertTrue(completed)
    }

    func testCombineLatest6WithDifferentFailureTypes() {
        enum TestError: Error {
            case test
        }

        let subject1 = PassthroughSubject<Int, TestError>()
        let subject2 = PassthroughSubject<String, TestError>()
        let subject3 = PassthroughSubject<Double, TestError>()
        let subject4 = PassthroughSubject<Bool, TestError>()
        let subject5 = PassthroughSubject<Character, TestError>()
        let subject6 = PassthroughSubject<Float, TestError>()

        var receivedValues: [(Int, String, Double, Bool, Character, Float)] = []

        Publishers.CombineLatest6(subject1, subject2, subject3, subject4, subject5, subject6)
            .sink(receiveCompletion: { _ in },
                  receiveValue: { receivedValues.append($0) })
            .store(in: &cancellables)

        subject1.send(1)
        subject2.send("A")
        subject3.send(1.5)
        subject4.send(true)
        subject5.send("X")
        subject6.send(3.14)

        XCTAssertEqual(receivedValues.count, 1)
        XCTAssertEqual(receivedValues[0].0, 1)
        XCTAssertEqual(receivedValues[0].1, "A")
        XCTAssertEqual(receivedValues[0].2, 1.5)
        XCTAssertEqual(receivedValues[0].3, true)
        XCTAssertEqual(receivedValues[0].4, "X")
        XCTAssertEqual(receivedValues[0].5, 3.14)
    }

    func testCombineLatest6WithFailure() {
        enum TestError: Error {
            case test
        }

        let subject1 = PassthroughSubject<Int, TestError>()
        let subject2 = PassthroughSubject<String, TestError>()
        let subject3 = PassthroughSubject<Double, TestError>()
        let subject4 = PassthroughSubject<Bool, TestError>()
        let subject5 = PassthroughSubject<Character, TestError>()
        let subject6 = PassthroughSubject<Float, TestError>()

        var receivedValues: [(Int, String, Double, Bool, Character, Float)] = []
        var receivedError: TestError?

        Publishers.CombineLatest6(subject1, subject2, subject3, subject4, subject5, subject6)
            .sink(receiveCompletion: { completion in
                      if case .failure(let error) = completion {
                          receivedError = error
                      }
                  },
                  receiveValue: { receivedValues.append($0) })
            .store(in: &cancellables)

        subject1.send(1)
        subject2.send("A")
        subject3.send(1.5)
        subject4.send(true)
        subject5.send("X")
        subject6.send(3.14)

        subject1.send(completion: .failure(.test))

        XCTAssertEqual(receivedValues.count, 1)
        XCTAssertEqual(receivedError, .test)
    }

    func testZip6WithMultipleValues() {
        let subject1 = PassthroughSubject<Int, Never>()
        let subject2 = PassthroughSubject<String, Never>()
        let subject3 = PassthroughSubject<Double, Never>()
        let subject4 = PassthroughSubject<Bool, Never>()
        let subject5 = PassthroughSubject<Character, Never>()
        let subject6 = PassthroughSubject<Float, Never>()

        var receivedValues: [(Int, String, Double, Bool, Character, Float)] = []

        Publishers.Zip6(subject1, subject2, subject3, subject4, subject5, subject6)
            .sink { receivedValues.append($0) }
            .store(in: &cancellables)

        // First set
        subject1.send(1)
        subject2.send("A")
        subject3.send(1.5)
        subject4.send(true)
        subject5.send("X")
        subject6.send(3.14)

        // Second set
        subject1.send(2)
        subject2.send("B")
        subject3.send(2.5)
        subject4.send(false)
        subject5.send("Y")
        subject6.send(6.28)

        XCTAssertEqual(receivedValues.count, 2)
        XCTAssertEqual(receivedValues[0].0, 1)
        XCTAssertEqual(receivedValues[1].0, 2)
    }

    func testCombineLatest5WithRapidChanges() {
        let subject1 = PassthroughSubject<Int, Never>()
        let subject2 = PassthroughSubject<String, Never>()
        let subject3 = PassthroughSubject<Double, Never>()
        let subject4 = PassthroughSubject<Bool, Never>()
        let subject5 = PassthroughSubject<Character, Never>()

        var receivedValues: [(Int, String, Double, Bool, Character)] = []

        Publishers.CombineLatest5(subject1, subject2, subject3, subject4, subject5)
            .sink { receivedValues.append($0) }
            .store(in: &cancellables)

        // Send initial values
        subject1.send(1)
        subject2.send("A")
        subject3.send(1.0)
        subject4.send(true)
        subject5.send("X")

        // Rapid changes
        subject1.send(2)
        subject1.send(3)
        subject2.send("B")
        subject3.send(2.0)
        subject4.send(false)
        subject5.send("Y")

        XCTAssertEqual(receivedValues.count, 7) // 1 initial + 6 changes
    }

    func testZip5WithUnevenEmission() {
        let subject1 = PassthroughSubject<Int, Never>()
        let subject2 = PassthroughSubject<String, Never>()
        let subject3 = PassthroughSubject<Double, Never>()
        let subject4 = PassthroughSubject<Bool, Never>()
        let subject5 = PassthroughSubject<Character, Never>()

        var receivedValues: [(Int, String, Double, Bool, Character)] = []

        Publishers.Zip5(subject1, subject2, subject3, subject4, subject5)
            .sink { receivedValues.append($0) }
            .store(in: &cancellables)

        // Send values in different order
        subject1.send(1)
        subject2.send("A")
        subject3.send(1.0)
        subject4.send(true)
        subject5.send("X")

        // Send extra values to some subjects
        subject1.send(2)
        subject1.send(3)
        subject2.send("B")

        // Only the first complete set should be emitted
        XCTAssertEqual(receivedValues.count, 1)
        XCTAssertEqual(receivedValues[0].0, 1)
        XCTAssertEqual(receivedValues[0].1, "A")
    }

    func testCombineLatest5WithJustValues() {
        let just1 = Just(1)
        let just2 = Just("A")
        let just3 = Just(1.0)
        let just4 = Just(true)
        let just5 = Just("X")

        var receivedValues: [(Int, String, Double, Bool, String)] = []

        Publishers.CombineLatest5(just1, just2, just3, just4, just5)
            .sink { receivedValues.append($0) }
            .store(in: &cancellables)

        XCTAssertEqual(receivedValues.count, 1)
        XCTAssertEqual(receivedValues[0].0, 1)
        XCTAssertEqual(receivedValues[0].1, "A")
        XCTAssertEqual(receivedValues[0].2, 1.0)
        XCTAssertEqual(receivedValues[0].3, true)
        XCTAssertEqual(receivedValues[0].4, "X")
    }

    func testZip5WithJustValues() {
        let just1 = Just(1)
        let just2 = Just("A")
        let just3 = Just(1.0)
        let just4 = Just(true)
        let just5 = Just("X")

        var receivedValues: [(Int, String, Double, Bool, String)] = []

        Publishers.Zip5(just1, just2, just3, just4, just5)
            .sink { receivedValues.append($0) }
            .store(in: &cancellables)

        XCTAssertEqual(receivedValues.count, 1)
        XCTAssertEqual(receivedValues[0].0, 1)
        XCTAssertEqual(receivedValues[0].1, "A")
        XCTAssertEqual(receivedValues[0].2, 1.0)
        XCTAssertEqual(receivedValues[0].3, true)
        XCTAssertEqual(receivedValues[0].4, "X")
    }
}
