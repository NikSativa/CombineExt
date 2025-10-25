import Combine
import CombineExt
import Foundation
import XCTest

final class SharedTests: XCTestCase {
    private var observers: Set<AnyCancellable> = []

    override func setUp() {
        super.setUp()
        observers.removeAll()
    }

    override func tearDown() {
        observers.removeAll()
        super.tearDown()
    }

    // MARK: - differs Tests

    func testDiffersWithIntProperty() {
        struct TestStruct {
            let value: Int
        }

        let lhs = TestStruct(value: 1)
        let rhs = TestStruct(value: 2)

        XCTAssertTrue(differs(lhs: lhs, rhs: rhs, keyPath: \.value))
        XCTAssertFalse(differs(lhs: lhs, rhs: lhs, keyPath: \.value))
    }

    func testDiffersWithStringProperty() {
        struct TestStruct {
            let name: String
        }

        let lhs = TestStruct(name: "Alice")
        let rhs = TestStruct(name: "Bob")

        XCTAssertTrue(differs(lhs: lhs, rhs: rhs, keyPath: \.name))
        XCTAssertFalse(differs(lhs: lhs, rhs: lhs, keyPath: \.name))
    }

    func testIsValueChangedWithOptionalProperty() {
        struct TestStruct {
            let optionalValue: Int?
        }

        let lhs = TestStruct(optionalValue: 1)
        let rhs = TestStruct(optionalValue: 2)
        let lhsNil = TestStruct(optionalValue: nil)

        XCTAssertTrue(differs(lhs: lhs, rhs: rhs, keyPath: \.optionalValue))
        XCTAssertTrue(differs(lhs: lhs, rhs: lhsNil, keyPath: \.optionalValue))
        XCTAssertTrue(differs(lhs: lhsNil, rhs: lhs, keyPath: \.optionalValue))
        XCTAssertFalse(differs(lhs: lhs, rhs: lhs, keyPath: \.optionalValue))
    }

    func testIsValueChangedWithBoolProperty() {
        struct TestStruct {
            let isEnabled: Bool
        }

        let lhs = TestStruct(isEnabled: true)
        let rhs = TestStruct(isEnabled: false)

        XCTAssertTrue(differs(lhs: lhs, rhs: rhs, keyPath: \.isEnabled))
        XCTAssertFalse(differs(lhs: lhs, rhs: lhs, keyPath: \.isEnabled))
    }

    func testIsValueChangedWithNestedProperty() {
        struct NestedStruct {
            let value: Int
        }

        struct TestStruct {
            let nested: NestedStruct
        }

        let lhs = TestStruct(nested: NestedStruct(value: 1))
        let rhs = TestStruct(nested: NestedStruct(value: 2))

        XCTAssertTrue(differs(lhs: lhs, rhs: rhs, keyPath: \.nested.value))
        XCTAssertFalse(differs(lhs: lhs, rhs: lhs, keyPath: \.nested.value))
    }

    func testIsValueChangedWithArrayProperty() {
        struct TestStruct {
            let items: [Int]
        }

        let lhs = TestStruct(items: [1, 2, 3])
        let rhs = TestStruct(items: [1, 2, 4])

        XCTAssertTrue(differs(lhs: lhs, rhs: rhs, keyPath: \.items))
        XCTAssertFalse(differs(lhs: lhs, rhs: lhs, keyPath: \.items))
    }

    func testIsValueChangedWithCustomEquatable() {
        struct CustomEquatable: Equatable {
            let value: Int
        }

        struct TestStruct {
            let custom: CustomEquatable
        }

        let lhs = TestStruct(custom: CustomEquatable(value: 1))
        let rhs = TestStruct(custom: CustomEquatable(value: 2))

        XCTAssertTrue(differs(lhs: lhs, rhs: rhs, keyPath: \.custom))
        XCTAssertFalse(differs(lhs: lhs, rhs: lhs, keyPath: \.custom))
    }

    func testIsValueChangedPerformance() {
        struct TestStruct {
            let value: Int
        }

        let lhs = TestStruct(value: 1)
        let rhs = TestStruct(value: 2)

        measure {
            for _ in 0..<10000 {
                _ = differs(lhs: lhs, rhs: rhs, keyPath: \.value)
            }
        }
    }

    // MARK: - ActionSubject Tests

    func testActionSubjectInitialization() {
        let actionSubject: ActionSubject = .init()
        XCTAssertNotNil(actionSubject)
    }

    func testActionSubjectSendingActions() {
        let actionSubject: ActionSubject = .init()
        var receivedCount = 0

        actionSubject
            .sink { receivedCount += 1 }
            .store(in: &observers)

        actionSubject.send(())
        actionSubject.send(())
        actionSubject.send(())

        XCTAssertEqual(receivedCount, 3)
    }

    func testActionSubjectNeverFails() {
        let actionSubject: ActionSubject = .init()
        var completionReceived = false

        actionSubject
            .sink(receiveCompletion: { _ in completionReceived = true },
                  receiveValue: { _ in })
            .store(in: &observers)

        actionSubject.send(())
        XCTAssertFalse(completionReceived)
    }

    func testActionSubjectWithMultipleSubscribers() {
        let actionSubject: ActionSubject = .init()
        var subscriber1Count = 0
        var subscriber2Count = 0

        actionSubject
            .sink { subscriber1Count += 1 }
            .store(in: &observers)

        actionSubject
            .sink { subscriber2Count += 1 }
            .store(in: &observers)

        actionSubject.send(())

        XCTAssertEqual(subscriber1Count, 1)
        XCTAssertEqual(subscriber2Count, 1)
    }

    func testActionSubjectWithVoidClosure() {
        let actionSubject: ActionSubject = .init()
        var actionTriggered = false

        actionSubject
            .sink { actionTriggered = true }
            .store(in: &observers)

        actionSubject.send(())

        XCTAssertTrue(actionTriggered)
    }

    func testActionSubjectUsagePattern() {
        let actionSubject: ActionSubject = .init()
        var actions: [String] = []

        actionSubject
            .sink { actions.append("Action 1") }
            .store(in: &observers)

        actionSubject
            .sink { actions.append("Action 2") }
            .store(in: &observers)

        actionSubject.send(())

        XCTAssertEqual(actions.count, 2)
        XCTAssertTrue(actions.contains("Action 1"))
        XCTAssertTrue(actions.contains("Action 2"))
    }

    func testActionSubjectChaining() {
        let actionSubject: ActionSubject = .init()
        var chainCount = 0

        actionSubject
            .map { "processed" }
            .sink { _ in chainCount += 1 }
            .store(in: &observers)

        actionSubject.send(())

        XCTAssertEqual(chainCount, 1)
    }

    // MARK: - EventSubject Tests

    func testEventSubjectInitialization() {
        let eventSubject: EventSubject<String> = .init()
        XCTAssertNotNil(eventSubject)
    }

    func testEventSubjectSendingValues() {
        let eventSubject: EventSubject<String> = .init()
        var receivedValues: [String] = []

        eventSubject
            .sink { receivedValues.append($0) }
            .store(in: &observers)

        eventSubject.send("Hello")
        eventSubject.send("World")

        XCTAssertEqual(receivedValues, ["Hello", "World"])
    }

    func testEventSubjectNeverFails() {
        let eventSubject: EventSubject<Int> = .init()
        var completionReceived = false

        eventSubject
            .sink(receiveCompletion: { _ in completionReceived = true },
                  receiveValue: { _ in })
            .store(in: &observers)

        eventSubject.send(42)
        XCTAssertFalse(completionReceived)
    }

    func testEventSubjectMultipleSubscribers() {
        let eventSubject: EventSubject<String> = .init()
        var subscriber1Values: [String] = []
        var subscriber2Values: [String] = []

        eventSubject
            .sink { subscriber1Values.append($0) }
            .store(in: &observers)

        eventSubject
            .sink { subscriber2Values.append($0) }
            .store(in: &observers)

        eventSubject.send("Test")

        XCTAssertEqual(subscriber1Values, ["Test"])
        XCTAssertEqual(subscriber2Values, ["Test"])
    }

    func testEventSubjectWithDifferentTypes() {
        let stringSubject: EventSubject<String> = .init()
        let intSubject: EventSubject<Int> = .init()
        var stringValues: [String] = []
        var intValues: [Int] = []

        stringSubject
            .sink { stringValues.append($0) }
            .store(in: &observers)

        intSubject
            .sink { intValues.append($0) }
            .store(in: &observers)

        stringSubject.send("Hello")
        intSubject.send(42)

        XCTAssertEqual(stringValues, ["Hello"])
        XCTAssertEqual(intValues, [42])
    }

    // MARK: - AnyCancellable Tests

    func testAnyCancellableTypeAlias() {
        let publisher = Just("test")
        let cancellable: AnyCancellable = publisher.sink { _ in }
        XCTAssertNotNil(cancellable)
    }

    func testAnyCancellableUsage() {
        var cancellables: Set<AnyCancellable> = []
        let publisher = Just("test")
        var receivedValue: String?

        publisher
            .sink { receivedValue = $0 }
            .store(in: &cancellables)

        XCTAssertEqual(receivedValue, "test")
        XCTAssertEqual(cancellables.count, 1)
    }

    func testAnyCancellableCancellation() {
        var cancellables: Set<AnyCancellable> = []
        let subject = PassthroughSubject<String, Never>()
        var receivedValues: [String] = []

        subject
            .sink { receivedValues.append($0) }
            .store(in: &cancellables)

        subject.send("First")
        cancellables.removeAll()
        subject.send("Second")

        XCTAssertEqual(receivedValues, ["First"])
    }

    // MARK: - Integration Tests

    func testSharedTypesIntegration() {
        let actionSubject: ActionSubject = .init()
        let eventSubject: EventSubject<String> = .init()
        var actionCount = 0
        var eventValues: [String] = []

        actionSubject
            .sink { actionCount += 1 }
            .store(in: &observers)

        eventSubject
            .sink { eventValues.append($0) }
            .store(in: &observers)

        actionSubject.send(())
        eventSubject.send("Event")

        XCTAssertEqual(actionCount, 1)
        XCTAssertEqual(eventValues, ["Event"])
    }

    func testSharedTypesMemoryManagement() {
        weak var weakActionSubject: ActionSubject?
        weak var weakEventSubject: EventSubject<String>?

        do {
            let actionSubject: ActionSubject = .init()
            let eventSubject: EventSubject<String> = .init()
            weakActionSubject = actionSubject
            weakEventSubject = eventSubject

            actionSubject.send(())
            eventSubject.send("Test")
        }

        // Give some time for deallocation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertNil(weakActionSubject)
            XCTAssertNil(weakEventSubject)
        }
    }

    func testSharedTypesWithCombineOperators() {
        let eventSubject: EventSubject<Int> = .init()
        var processedValues: [String] = []

        eventSubject
            .map { "Value: \($0)" }
            .filter { $0.contains("2") }
            .sink { processedValues.append($0) }
            .store(in: &observers)

        eventSubject.send(1)
        eventSubject.send(2)
        eventSubject.send(3)

        XCTAssertEqual(processedValues, ["Value: 2"])
    }

    // MARK: - CustomMirror Tests

    func testCustomMirrorWithIgnoredState() {
        struct TestStruct {
            let value: Int
        }

        @IgnoredState
        var ignoredValue = TestStruct(value: 42)

        let mirror = _ignoredValue.customMirror
        XCTAssertEqual(mirror.children.count, 1)

        let firstChild = mirror.children.first!
        XCTAssertEqual(firstChild.label, "value")
        XCTAssertEqual(firstChild.value as? Int, 42)
    }

    func testCustomMirrorWithComplexIgnoredState() {
        struct NestedStruct {
            let name: String
            let count: Int
        }

        struct TestStruct {
            let nested: NestedStruct
            let flag: Bool
        }

        @IgnoredState
        var ignoredValue = TestStruct(nested: NestedStruct(name: "Test", count: 5), flag: true)

        let mirror = _ignoredValue.customMirror
        XCTAssertEqual(mirror.children.count, 2)

        let children = Array(mirror.children)
        let nestedChild = children.first { $0.label == "nested" }
        let flagChild = children.first { $0.label == "flag" }

        XCTAssertNotNil(nestedChild)
        XCTAssertNotNil(flagChild)
        XCTAssertEqual(flagChild?.value as? Bool, true)
    }

    // MARK: - LocalizedStringResource Tests (iOS 16+)

    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    func testLocalizedStringResourceWithUIState() {
        struct LocalizableStruct: Equatable, CustomLocalizedStringResourceConvertible {
            let value: String

            var localizedStringResource: LocalizedStringResource {
                LocalizedStringResource(stringLiteral: value)
            }
        }

        @UIState
        var state = LocalizableStruct(value: "Hello World")

        let resource = state.localizedStringResource
        XCTAssertNotNil(resource)
    }

    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    func testLocalizedStringResourceWithManagedState() {
        struct LocalizableStruct: BehavioralStateContract, CustomLocalizedStringResourceConvertible {
            let value: String

            var localizedStringResource: LocalizedStringResource {
                LocalizedStringResource(stringLiteral: value)
            }

            mutating func applyRules() {}

            @SubscriptionBuilder
            static func applyBindingRules(to state: RulesPublisher) -> [AnyCancellable] {
                // No binding rules needed for this test
            }

            @AnyTokenBuilder<Any>
            static func applyAnyRules(to state: UIBinding<Self>) -> [Any] {
                // No any rules needed for this test
            }
        }

        @ManagedState
        var state = LocalizableStruct(value: "Test Value")

        let resource = state.localizedStringResource
        XCTAssertNotNil(resource)
    }

    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    func testLocalizedStringResourceWithUIBinding() {
        struct LocalizableStruct: CustomLocalizedStringResourceConvertible {
            let value: String

            var localizedStringResource: LocalizedStringResource {
                LocalizedStringResource(stringLiteral: value)
            }
        }

        let source = LocalizableStruct(value: "Binding Value")
        let binding = UIBinding(get: { source }, set: { _ in })

        let resource = binding.localizedStringResource
        XCTAssertNotNil(resource)
    }
}
