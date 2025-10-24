import Combine
import CombineExt
import Foundation
import XCTest

final class SharedTests: XCTestCase {
    // MARK: - AnyCancellable Tests

    func testAnyCancellableTypeAlias() {
        // Test that AnyCancellable is properly aliased
        let cancellable: AnyCancellable = AnyCancellable {}

        // Should compile without issues
        XCTAssertNotNil(cancellable)
    }

    func testAnyCancellableUsage() {
        var cancellables = Set<AnyCancellable>()

        let subject = PassthroughSubject<String, Never>()
        var receivedValues: [String] = []

        subject
            .sink { value in
                receivedValues.append(value)
            }
            .store(in: &cancellables)

        subject.send("Hello")
        subject.send("World")

        XCTAssertEqual(receivedValues, ["Hello", "World"])
        XCTAssertEqual(cancellables.count, 1)
    }

    func testAnyCancellableCancellation() {
        var cancellables = Set<AnyCancellable>()

        let subject = PassthroughSubject<String, Never>()
        var receivedValues: [String] = []

        subject
            .sink { value in
                receivedValues.append(value)
            }
            .store(in: &cancellables)

        subject.send("Hello")

        // Cancel all subscriptions
        cancellables.removeAll()

        subject.send("World")

        XCTAssertEqual(receivedValues, ["Hello"]) // Only first value should be received
    }

    // MARK: - EventSubject Tests

    func testEventSubjectInitialization() {
        let subject: EventSubject<String> = .init()

        // Should compile without issues
        XCTAssertNotNil(subject)
    }

    func testEventSubjectSendingValues() {
        let subject: EventSubject<String> = .init()
        var receivedValues: [String] = []

        let cancellable = subject.sink { value in
            receivedValues.append(value)
        }

        subject.send("Hello")
        subject.send("World")
        subject.send("Swift")

        XCTAssertEqual(receivedValues, ["Hello", "World", "Swift"])

        cancellable.cancel()
    }

    func testEventSubjectWithDifferentTypes() {
        let stringSubject: EventSubject<String> = .init()
        let intSubject: EventSubject<Int> = .init()
        let boolSubject: EventSubject<Bool> = .init()

        var receivedStrings: [String] = []
        var receivedInts: [Int] = []
        var receivedBools: [Bool] = []

        let cancellable1 = stringSubject.sink { receivedStrings.append($0) }
        let cancellable2 = intSubject.sink { receivedInts.append($0) }
        let cancellable3 = boolSubject.sink { receivedBools.append($0) }

        stringSubject.send("Hello")
        intSubject.send(42)
        boolSubject.send(true)

        XCTAssertEqual(receivedStrings, ["Hello"])
        XCTAssertEqual(receivedInts, [42])
        XCTAssertEqual(receivedBools, [true])

        cancellable1.cancel()
        cancellable2.cancel()
        cancellable3.cancel()
    }

    func testEventSubjectNeverFails() {
        let subject: EventSubject<String> = .init()
        var completionReceived = false

        let cancellable = subject.sink(receiveCompletion: { _ in completionReceived = true },
                                       receiveValue: { _ in })

        subject.send("Hello")
        subject.send(completion: .finished)

        XCTAssertTrue(completionReceived)

        cancellable.cancel()
    }

    func testEventSubjectMultipleSubscribers() {
        let subject: EventSubject<String> = .init()
        var receivedValues1: [String] = []
        var receivedValues2: [String] = []

        let cancellable1 = subject.sink { receivedValues1.append($0) }
        let cancellable2 = subject.sink { receivedValues2.append($0) }

        subject.send("Hello")
        subject.send("World")

        XCTAssertEqual(receivedValues1, ["Hello", "World"])
        XCTAssertEqual(receivedValues2, ["Hello", "World"])

        cancellable1.cancel()
        cancellable2.cancel()
    }

    // MARK: - ActionSubject Tests

    func testActionSubjectInitialization() {
        let subject: ActionSubject = .init()

        // Should compile without issues
        XCTAssertNotNil(subject)
    }

    func testActionSubjectSendingActions() {
        let subject: ActionSubject = .init()
        var actionCount = 0

        let cancellable = subject.sink {
            actionCount += 1
        }

        subject.send(())
        subject.send(())
        subject.send(())

        XCTAssertEqual(actionCount, 3)

        cancellable.cancel()
    }

    func testActionSubjectWithMultipleSubscribers() {
        let subject: ActionSubject = .init()
        var actionCount1 = 0
        var actionCount2 = 0

        let cancellable1 = subject.sink { actionCount1 += 1 }
        let cancellable2 = subject.sink { actionCount2 += 1 }

        subject.send(())
        subject.send(())

        XCTAssertEqual(actionCount1, 2)
        XCTAssertEqual(actionCount2, 2)

        cancellable1.cancel()
        cancellable2.cancel()
    }

    func testActionSubjectNeverFails() {
        let subject: ActionSubject = .init()
        var completionReceived = false

        let cancellable = subject.sink(receiveCompletion: { _ in completionReceived = true },
                                       receiveValue: { _ in })

        subject.send(())
        subject.send(completion: .finished)

        XCTAssertTrue(completionReceived)

        cancellable.cancel()
    }

    func testActionSubjectUsagePattern() {
        let buttonTapSubject: ActionSubject = .init()
        var buttonTapped = false

        let cancellable = buttonTapSubject.sink {
            buttonTapped = true
        }

        // Simulate button tap
        buttonTapSubject.send(())

        XCTAssertTrue(buttonTapped)

        cancellable.cancel()
    }

    func testActionSubjectWithVoidClosure() {
        let subject: ActionSubject = .init()
        var closureCalled = false

        let cancellable = subject.sink {
            closureCalled = true
        }

        subject.send(())

        XCTAssertTrue(closureCalled)

        cancellable.cancel()
    }

    func testActionSubjectChaining() {
        let subject: ActionSubject = .init()
        var step1 = false

        var cancellables = Set<AnyCancellable>()
        subject
            .sink { step1 = true }
            .store(in: &cancellables)

        subject.send(())

        XCTAssertTrue(step1)
    }

    // MARK: - Integration Tests

    func testSharedTypesIntegration() {
        let eventSubject: EventSubject<String> = .init()
        let actionSubject: ActionSubject = .init()
        var cancellables = Set<AnyCancellable>()

        var receivedEvents: [String] = []
        var actionCount = 0

        eventSubject
            .sink { receivedEvents.append($0) }
            .store(in: &cancellables)

        actionSubject
            .sink { actionCount += 1 }
            .store(in: &cancellables)

        eventSubject.send("Hello")
        actionSubject.send(())
        eventSubject.send("World")
        actionSubject.send(())

        XCTAssertEqual(receivedEvents, ["Hello", "World"])
        XCTAssertEqual(actionCount, 2)
        XCTAssertEqual(cancellables.count, 2)
    }

    func testSharedTypesWithCombineOperators() {
        let eventSubject: EventSubject<String> = .init()
        var cancellables = Set<AnyCancellable>()

        var receivedValues: [String] = []

        eventSubject
            .map { $0.uppercased() }
            .filter { $0.count > 3 }
            .sink { receivedValues.append($0) }
            .store(in: &cancellables)

        eventSubject.send("hello")
        eventSubject.send("hi")
        eventSubject.send("world")
        eventSubject.send("swift")

        XCTAssertEqual(receivedValues, ["HELLO", "WORLD", "SWIFT"])
    }

    func testSharedTypesMemoryManagement() {
        weak var weakEventSubject: EventSubject<String>?
        weak var weakActionSubject: ActionSubject?

        do {
            let eventSubject: EventSubject<String> = .init()
            let actionSubject: ActionSubject = .init()

            weakEventSubject = eventSubject
            weakActionSubject = actionSubject

            var cancellables = Set<AnyCancellable>()

            eventSubject
                .sink { _ in }
                .store(in: &cancellables)

            actionSubject
                .sink { _ in }
                .store(in: &cancellables)
        }

        // Subjects should be deallocated after the scope
        XCTAssertNil(weakEventSubject)
        XCTAssertNil(weakActionSubject)
    }
}
