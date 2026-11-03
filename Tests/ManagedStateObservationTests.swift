import Combine
import CombineExt
import Foundation
import Observation
import XCTest

@available(iOS 17, macOS 14, tvOS 17, watchOS 10, visionOS 1, *)
final class ManagedStateObservationTests: XCTestCase {
    func testSetterChangeNotifiesOnce() {
        let subject = ManagedState(wrappedValue: ObservedModel())
        let recorder = ObservationRecorder { subject.wrappedValue }

        subject.wrappedValue = ObservedModel(amount: 1, title: "", isEnabled: false)

        XCTAssertEqual(recorder.valuesReadInOnChange, [ObservedModel()])
        XCTAssertEqual(subject.wrappedValue, ObservedModel(amount: 1, title: "", isEnabled: false))
    }

    func testWithLockChangingThreeFieldsNotifiesOnce() {
        let subject = ManagedState(wrappedValue: ObservedModel())
        let recorder = ObservationRecorder { subject.wrappedValue }

        subject.withLock { value in
            value.amount = 1
            value.title = "title"
            value.isEnabled = true
        }

        XCTAssertEqual(recorder.valuesReadInOnChange, [ObservedModel()])
        XCTAssertEqual(subject.wrappedValue, ObservedModel(amount: 1, title: "title", isEnabled: true))
    }

    func testBindingChangeNotifies() {
        let subject = ManagedState(wrappedValue: ObservedModel())
        let recorder = ObservationRecorder { subject.wrappedValue }
        let binding: UIBinding<Int> = subject(\.amount)

        binding.wrappedValue = 2

        XCTAssertEqual(recorder.valuesReadInOnChange, [ObservedModel()])
        XCTAssertEqual(subject.wrappedValue, ObservedModel(amount: 2, title: "", isEnabled: false))
    }

    func testDynamicMemberSetterNotifies() {
        let subject = ManagedState(wrappedValue: ObservedModel())
        let recorder = ObservationRecorder { subject.wrappedValue }

        subject.title = "title"

        XCTAssertEqual(recorder.valuesReadInOnChange, [ObservedModel()])
        XCTAssertEqual(subject.wrappedValue, ObservedModel(amount: 0, title: "title", isEnabled: false))
    }

    func testEqualValueDoesNotNotify() {
        let subject = ManagedState(wrappedValue: ObservedModel(amount: 1, title: "title", isEnabled: true))
        let recorder = ObservationRecorder { subject.wrappedValue }

        subject.wrappedValue = ObservedModel(amount: 1, title: "title", isEnabled: true)
        subject.amount = 1
        subject.withLock { value in
            value.title = "title"
        }

        XCTAssertEqual(recorder.valuesReadInOnChange, [])
    }

    func testChangeOfAnyFieldNotifiesOnceWithFinalResultOfRules() {
        let cases: [(name: String, change: (ManagedState<RuledModel>) -> Void, result: RuledModel)] = [
            (name: "amount through the setter",
             change: { subject in
                 subject.wrappedValue.amount = 6
             },
             result: RuledModel(amount: 6, doubled: 12, isLarge: true, summary: "6 x 2 = 12")),
            (name: "doubled through the dynamic member setter",
             change: { subject in
                 subject.doubled = 4
             },
             result: RuledModel(amount: 0, doubled: 4, isLarge: false, summary: "0 x 2 = 4")),
            (name: "isLarge through a binding",
             change: { subject in
                 let binding: UIBinding<Bool> = subject(\.isLarge)
                 binding.wrappedValue = true
             },
             result: RuledModel(amount: 0, doubled: 0, isLarge: true, summary: "0 x 2 = 0")),
            (name: "three fields through withLock",
             change: { subject in
                 subject.withLock { value in
                     value.amount = 3
                     value.isLarge = true
                     value.summary = "custom"
                 }
             },
             result: RuledModel(amount: 3, doubled: 6, isLarge: false, summary: "3 x 2 = 6"))
        ]

        for testCase in cases {
            let subject = ManagedState(wrappedValue: RuledModel())
            let recorder = ObservationRecorder { subject.wrappedValue }
            var publishedValues: [RuledModel] = []
            let cancellable = subject.publisher.sink { value in
                publishedValues.append(value)
            }

            testCase.change(subject)

            XCTAssertEqual(recorder.valuesReadInOnChange, [RuledModel()], testCase.name)
            XCTAssertEqual(subject.wrappedValue, testCase.result, testCase.name)
            XCTAssertEqual(publishedValues, [RuledModel(), testCase.result], testCase.name)
            cancellable.cancel()
        }
    }

    func testChangeThatRulesRevertDoesNotNotify() {
        let subject = ManagedState(wrappedValue: RuledModel())
        let recorder = ObservationRecorder { subject.wrappedValue }
        var publishedValues: [RuledModel] = []
        let cancellable = subject.publisher.sink { value in
            publishedValues.append(value)
        }

        subject.summary = "custom"

        XCTAssertEqual(recorder.valuesReadInOnChange, [])
        XCTAssertEqual(subject.wrappedValue, RuledModel())
        XCTAssertEqual(publishedValues, [RuledModel()])
        cancellable.cancel()
    }

    func testDynamicMemberReadRegistersAccess() {
        let subject = ManagedState(wrappedValue: ObservedModel())
        let recorder = ObservationRecorder { subject.isEnabled as Bool }

        subject.isEnabled = true

        XCTAssertEqual(recorder.valuesReadInOnChange, [false])
        XCTAssertTrue(subject.isEnabled)
    }

    func testObservableViewModelNotifiesThroughComputedProperty() {
        let viewModel = ObservedViewModel()
        let recorder = ObservationRecorder { viewModel.state }

        viewModel.rename(to: "renamed")

        XCTAssertEqual(recorder.valuesReadInOnChange, [ObservedModel()])
        XCTAssertEqual(viewModel.state, ObservedModel(amount: 0, title: "renamed", isEnabled: false))
    }

    func testObserverReadsOldValueInOnChangeWithRecursiveLocks() {
        let locks: [ManagedStateLock] = [
            .absent,
            .synced,
            .custom(NSRecursiveLock())
        ]

        for lock in locks {
            let subject = ManagedState(wrappedValue: ObservedModel(), lock: lock)
            let recorder = ObservationRecorder { subject.wrappedValue }

            subject.amount = 5

            XCTAssertEqual(recorder.valuesReadInOnChange, [ObservedModel()], "lock: \(lock)")
            XCTAssertEqual(subject.wrappedValue, ObservedModel(amount: 5, title: "", isEnabled: false), "lock: \(lock)")
        }
    }
}

private struct ObservedModel: BehavioralStateContract {
    var amount: Int = 0
    var title: String = ""
    var isEnabled: Bool = false

    mutating func applyRules() {}

    @SubscriptionBuilder
    static func applyBindingRules(to state: RulesPublisher) -> [AnyCancellable] {}

    @AnyTokenBuilder<Any>
    static func applyAnyRules(to state: UIBinding<Self>) -> [Any] {}
}

private struct RuledModel: BehavioralStateContract {
    var amount: Int = 0
    var doubled: Int = 0
    var isLarge: Bool = false
    var summary: String = "0 x 2 = 0"

    mutating func applyRules() {
        summary = "\(amount) x 2 = \(doubled)"
    }

    @SubscriptionBuilder
    static func applyBindingRules(to state: RulesPublisher) -> [AnyCancellable] {
        state.bind(to: \.amount) { model in
            model.doubled = model.amount * 2
        }
        state.bind(to: \.doubled) { model in
            model.isLarge = model.doubled > 10
        }
    }

    @AnyTokenBuilder<Any>
    static func applyAnyRules(to state: UIBinding<Self>) -> [Any] {}
}

@available(iOS 17, macOS 14, tvOS 17, watchOS 10, visionOS 1, *)
@Observable
private final class ObservedViewModel {
    @ObservationIgnored
    @ManagedState
    private var viewState = ObservedModel()

    var state: ObservedModel {
        return viewState
    }

    func rename(to title: String) {
        viewState.title = title
    }
}

@available(iOS 17, macOS 14, tvOS 17, watchOS 10, visionOS 1, *)
private final class ObservationRecorder<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private let read: () -> Value
    private var recordedValues: [Value] = []

    var valuesReadInOnChange: [Value] {
        return lock.withLock {
            return recordedValues
        }
    }

    init(_ read: @escaping () -> Value) {
        self.read = read
        _ = track()
    }

    private func track() -> Value {
        return withObservationTracking {
            return read()
        } onChange: { [self] in
            let value = track()
            lock.withLock {
                recordedValues.append(value)
            }
        }
    }
}
