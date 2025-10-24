import Combine
import CombineExt
import Foundation
import XCTest

@available(iOS 13.0, macOS 10.15, *)
final class ObservableObjectTests: XCTestCase {
    private var cancellables: Set<AnyCancellable> = []

    override func setUp() {
        super.setUp()
        cancellables.removeAll()
    }

    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }

    // MARK: - ValueSubject ObservableObject Tests

    func testValueSubjectObservableObject() {
        let valueSubject = ValueSubject(wrappedValue: 0)
        var changeCount = 0

        valueSubject.objectWillChange
            .sink { changeCount += 1 }
            .store(in: &cancellables)

        // Initial subscription triggers immediately
        XCTAssertEqual(changeCount, 1)

        // Changing value should trigger change
        valueSubject.wrappedValue = 1
        XCTAssertEqual(changeCount, 2)

        valueSubject.wrappedValue = 2
        XCTAssertEqual(changeCount, 3)
    }

    func testValueSubjectObservableObjectWithStruct() {
        struct TestStruct: Equatable {
            var name: String
            var age: Int
        }

        let valueSubject = ValueSubject(wrappedValue: TestStruct(name: "Alice", age: 30))
        var changeCount = 0

        valueSubject.objectWillChange
            .sink { changeCount += 1 }
            .store(in: &cancellables)

        // Initial subscription triggers immediately
        XCTAssertEqual(changeCount, 1)

        // Changing value should trigger change
        valueSubject.wrappedValue = TestStruct(name: "Bob", age: 25)
        XCTAssertEqual(changeCount, 2)

        // Changing to same value should trigger change (objectWillChange fires before check)
        valueSubject.wrappedValue = TestStruct(name: "Bob", age: 25)
        XCTAssertEqual(changeCount, 3)

        // Changing nested property should trigger change (ValueSubject tracks nested changes)
        valueSubject.wrappedValue.name = "Charlie"
        XCTAssertEqual(changeCount, 4)

        // Changing another nested property should also trigger change
        valueSubject.wrappedValue.age = 35
        XCTAssertEqual(changeCount, 5)

        // Changing nested property again should trigger change
        valueSubject.wrappedValue.name = "David"
        XCTAssertEqual(changeCount, 6)
    }

    // MARK: - UIState ObservableObject Tests

    func testUIStateObservableObject() {
        let uiState = UIState(wrappedValue: 0)
        var changeCount = 0

        uiState.objectWillChange
            .sink { changeCount += 1 }
            .store(in: &cancellables)

        // Initial subscription triggers immediately
        XCTAssertEqual(changeCount, 1)

        // Changing value should trigger change
        uiState.wrappedValue = 1
        XCTAssertEqual(changeCount, 2)

        uiState.wrappedValue = 2
        XCTAssertEqual(changeCount, 3)
    }

    func testUIStateObservableObjectWithStruct() {
        struct TestStruct: Equatable {
            var name: String
            var age: Int
        }

        let uiState = UIState(wrappedValue: TestStruct(name: "Alice", age: 30))
        var changeCount = 0

        uiState.objectWillChange
            .sink { changeCount += 1 }
            .store(in: &cancellables)

        // Initial subscription triggers immediately
        XCTAssertEqual(changeCount, 1)

        // Changing value should trigger change
        uiState.wrappedValue = TestStruct(name: "Bob", age: 25)
        XCTAssertEqual(changeCount, 2)

        // Changing to same value should not trigger change
        uiState.wrappedValue = TestStruct(name: "Bob", age: 25)
        XCTAssertEqual(changeCount, 2)
    }

    // MARK: - UIBinding and IgnoredState Tests

    func testUIBindingAndIgnoredStateUsage() {
        // Test that UIBinding and IgnoredState work correctly in ObservableObject contexts
        let uiState = UIState(wrappedValue: 0)
        let binding = UIBinding(publisher: uiState.publisher,
                                get: { uiState.wrappedValue },
                                set: { uiState.wrappedValue = $0 })

        var ignoredState = IgnoredState(wrappedValue: "cache")

        // Test that they can be used in ObservableObject classes
        class TestViewModel: ObservableObject {
            @UIState
            var state = UIState(wrappedValue: 0)
            @IgnoredState
            var cache = IgnoredState(wrappedValue: "test")
        }

        let viewModel = TestViewModel()
        XCTAssertEqual(viewModel.state.wrappedValue, 0)
        XCTAssertEqual(viewModel.cache.wrappedValue, "test")

        // Test binding functionality
        binding.wrappedValue = 42
        XCTAssertEqual(binding.wrappedValue, 42)
        XCTAssertEqual(uiState.wrappedValue, 42)

        // Test ignored state functionality
        ignoredState.wrappedValue = "updated"
        XCTAssertEqual(ignoredState.wrappedValue, "updated")
    }

    // MARK: - ManagedState ObservableObject Tests

    func testManagedStateObservableObject() {
        struct TestModel: BehavioralStateContract {
            var value: Int = 0

            mutating func applyRules() {}

            @SubscriptionBuilder
            static func applyBindingRules(to state: RulesPublisher) -> [AnyCancellable] { [] }

            @AnyTokenBuilder<Any>
            static func applyAnyRules(to state: UIBinding<Self>) -> [Any] { [] }
        }

        let managedState = ManagedState(wrappedValue: TestModel())
        var changeCount = 0

        managedState.objectWillChange
            .sink { changeCount += 1 }
            .store(in: &cancellables)

        // ManagedState triggers on initial subscription
        XCTAssertEqual(changeCount, 1)

        // Changing value should trigger change
        managedState.wrappedValue = TestModel(value: 1)
        XCTAssertEqual(changeCount, 2)

        managedState.wrappedValue = TestModel(value: 2)
        XCTAssertEqual(changeCount, 3)

        // Changing nested property should also trigger change
        managedState.wrappedValue.value = 3
        XCTAssertEqual(changeCount, 4)

        // Changing nested property again should trigger change
        managedState.wrappedValue.value = 4
        XCTAssertEqual(changeCount, 5)
    }

    // MARK: - Integration Tests

    func testObservableObjectIntegrationWithMultipleTypes() {
        let valueSubject = ValueSubject(wrappedValue: 0)
        let uiState = UIState(wrappedValue: "Hello")

        var valueChangeCount = 0
        var uiChangeCount = 0

        valueSubject.objectWillChange
            .sink { valueChangeCount += 1 }
            .store(in: &cancellables)

        uiState.objectWillChange
            .sink { uiChangeCount += 1 }
            .store(in: &cancellables)

        // Initial subscriptions trigger immediately
        XCTAssertEqual(valueChangeCount, 1)
        XCTAssertEqual(uiChangeCount, 1)

        // Change values
        valueSubject.wrappedValue = 1
        uiState.wrappedValue = "World"

        // Check that all publishers emitted
        XCTAssertEqual(valueChangeCount, 2)
        XCTAssertEqual(uiChangeCount, 2)
    }

    func testObservableObjectWithNestedProperties() {
        struct User: Equatable {
            var name: String
            var age: Int
        }

        let valueSubject = ValueSubject(wrappedValue: User(name: "Alice", age: 30))
        var changeCount = 0

        valueSubject.objectWillChange
            .sink { changeCount += 1 }
            .store(in: &cancellables)

        // Initial subscription triggers immediately
        XCTAssertEqual(changeCount, 1)

        // Changing nested property should trigger change
        valueSubject.wrappedValue.name = "Bob"
        XCTAssertEqual(changeCount, 2)

        valueSubject.wrappedValue.age = 25
        XCTAssertEqual(changeCount, 3)
    }

    func testObservableObjectWithArrayValues() {
        let valueSubject = ValueSubject(wrappedValue: [1, 2, 3])
        var changeCount = 0

        valueSubject.objectWillChange
            .sink { changeCount += 1 }
            .store(in: &cancellables)

        // Initial subscription triggers immediately
        XCTAssertEqual(changeCount, 1)

        // Changing array should trigger change
        valueSubject.wrappedValue.append(4)
        XCTAssertEqual(changeCount, 2)

        valueSubject.wrappedValue.removeLast()
        XCTAssertEqual(changeCount, 3)
    }

    func testObservableObjectWithOptionalValues() {
        let valueSubject = ValueSubject(wrappedValue: String?.none)
        var changeCount = 0

        valueSubject.objectWillChange
            .sink { changeCount += 1 }
            .store(in: &cancellables)

        // Initial subscription triggers immediately
        XCTAssertEqual(changeCount, 1)

        // Changing from nil to value should trigger change
        valueSubject.wrappedValue = "Hello"
        XCTAssertEqual(changeCount, 2)

        // Changing from value to nil should trigger change
        valueSubject.wrappedValue = nil
        XCTAssertEqual(changeCount, 3)
    }

    func testObservableObjectPerformance() {
        let valueSubject = ValueSubject(wrappedValue: 0)
        var changeCount = 0

        valueSubject.objectWillChange
            .sink { changeCount += 1 }
            .store(in: &cancellables)

        // Initial subscription triggers immediately
        XCTAssertEqual(changeCount, 1)

        measure {
            for i in 0..<1000 {
                valueSubject.wrappedValue = i
            }
        }

        XCTAssertEqual(changeCount, 10001) // 1 initial + 10000 changes (10x per change)
    }

    func testObservableObjectWithMultipleSubscribers() {
        let valueSubject = ValueSubject(wrappedValue: 0)
        var changeCount1 = 0
        var changeCount2 = 0

        valueSubject.objectWillChange
            .sink { changeCount1 += 1 }
            .store(in: &cancellables)

        valueSubject.objectWillChange
            .sink { changeCount2 += 1 }
            .store(in: &cancellables)

        // Both subscribers should receive the same number of changes
        // Initial subscriptions trigger immediately
        XCTAssertEqual(changeCount1, 1)
        XCTAssertEqual(changeCount2, 1)

        valueSubject.wrappedValue = 1
        valueSubject.wrappedValue = 2

        XCTAssertEqual(changeCount1, 3)
        XCTAssertEqual(changeCount2, 3)
    }

    func testObservableObjectWithCancellation() {
        let valueSubject = ValueSubject(wrappedValue: 0)
        var changeCount = 0

        let cancellable = valueSubject.objectWillChange
            .sink { changeCount += 1 }

        // Initial subscription triggers immediately
        XCTAssertEqual(changeCount, 1)

        // First change should be received
        valueSubject.wrappedValue = 1
        XCTAssertEqual(changeCount, 2)

        // Cancel subscription
        cancellable.cancel()

        // Subsequent changes should not be received
        valueSubject.wrappedValue = 2
        XCTAssertEqual(changeCount, 2)
    }
}
