import Combine
import CombineExt
import Foundation
import Observation
import SwiftUI
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

    func testSwiftUIBindingSetterNotifies() {
        let subject = ManagedState(wrappedValue: ObservedModel())
        let recorder = ObservationRecorder { subject.wrappedValue }

        subject.title.wrappedValue = "title"

        XCTAssertEqual(recorder.valuesReadInOnChange, [ObservedModel()])
        XCTAssertEqual(subject.wrappedValue, ObservedModel(amount: 0, title: "title", isEnabled: false))
    }

    func testEqualValueDoesNotNotify() {
        let subject = ManagedState(wrappedValue: ObservedModel(amount: 1, title: "title", isEnabled: true))
        let recorder = ObservationRecorder { subject.wrappedValue }

        subject.wrappedValue = ObservedModel(amount: 1, title: "title", isEnabled: true)
        subject.wrappedValue.amount = 1
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
            (name: "doubled through the SwiftUI binding",
             change: { subject in
                 subject.doubled.wrappedValue = 4
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

        subject.wrappedValue.summary = "custom"

        XCTAssertEqual(recorder.valuesReadInOnChange, [])
        XCTAssertEqual(subject.wrappedValue, RuledModel())
        XCTAssertEqual(publishedValues, [RuledModel()])
        cancellable.cancel()
    }

    func testSwiftUIBindingReadRegistersAccess() {
        let subject = ManagedState(wrappedValue: ObservedModel())
        let recorder = ObservationRecorder { subject.isEnabled.wrappedValue }

        subject.isEnabled.wrappedValue = true

        XCTAssertEqual(recorder.valuesReadInOnChange, [false])
        XCTAssertTrue(subject[\.isEnabled])
    }

    func testObservableViewModelNotifiesThroughComputedProperty() {
        let viewModel = ObservedViewModel()
        let recorder = ObservationRecorder { viewModel.state }

        viewModel.rename(to: "renamed")

        XCTAssertEqual(recorder.valuesReadInOnChange, [ObservedModel()])
        XCTAssertEqual(viewModel.state, ObservedModel(amount: 0, title: "renamed", isEnabled: false))
    }

    func testViewModelWithoutMacroTracksWholeValueAndField() {
        let viewModel = ConformingViewModel()
        let wholeRecorder = ObservationRecorder { viewModel.viewState }
        let titleRecorder = ObservationRecorder { viewModel.$viewState[\.title] }

        viewModel.$viewState.isEnabled.wrappedValue = true
        viewModel.rename(to: "renamed")

        XCTAssertEqual(wholeRecorder.valuesReadInOnChange, [ObservedModel(), ObservedModel(isEnabled: true)])
        XCTAssertEqual(titleRecorder.valuesReadInOnChange, [""])
    }

    func testObserverReadsOldValueInOnChangeWithRecursiveLocks() {
        let locks: [StateLock] = [
            .absent,
            .synced,
            .custom(NSRecursiveLock())
        ]

        for lock in locks {
            let subject = ManagedState(wrappedValue: ObservedModel(), lock: lock)
            let recorder = ObservationRecorder { subject.wrappedValue }

            subject.wrappedValue.amount = 5

            XCTAssertEqual(recorder.valuesReadInOnChange, [ObservedModel()], "lock: \(lock)")
            XCTAssertEqual(subject.wrappedValue, ObservedModel(amount: 5, title: "", isEnabled: false), "lock: \(lock)")
        }
    }

    func testFieldReaderIsNotNotifiedForChangeOfOtherFields() {
        let subject = ManagedState(wrappedValue: FieldModel())
        let recorder = ObservationRecorder { subject[\.amount] }

        subject.wrappedValue.title = "title"
        subject.wrappedValue.trip.seats = 2
        subject.wrappedValue.payload.text = "text"

        XCTAssertEqual(recorder.valuesReadInOnChange, [])
    }

    func testFieldReaderIsNotifiedOnceForEachChangeOfItsField() {
        let subject = ManagedState(wrappedValue: FieldModel())
        let recorder = ObservationRecorder { subject[\.amount] }

        subject.wrappedValue.amount = 5
        subject.wrappedValue.title = "title"
        subject.wrappedValue.amount = 6

        XCTAssertEqual(recorder.valuesReadInOnChange, [0, 5])
        XCTAssertEqual(subject.wrappedValue, FieldModel(amount: 6, title: "title"))
    }

    func testWholeValueReaderIsNotifiedForChangeOfEachField() {
        let subject = ManagedState(wrappedValue: FieldModel())
        let fieldRecorder = ObservationRecorder { subject[\.amount] }
        let wholeRecorder = ObservationRecorder { subject.wrappedValue }

        subject.wrappedValue.amount = 1
        subject.wrappedValue.title = "title"
        subject.wrappedValue.trip.seats = 2

        XCTAssertEqual(fieldRecorder.valuesReadInOnChange, [0])
        XCTAssertEqual(wholeRecorder.valuesReadInOnChange, [
            FieldModel(),
            FieldModel(amount: 1),
            FieldModel(amount: 1, title: "title")
        ])
    }

    func testReadOnlyFieldReaderIsNotifiedOnlyWhenItsValueChanges() {
        let subject = ManagedState(wrappedValue: FieldModel())
        let recorder = ObservationRecorder { subject[\.amountText] }

        subject.wrappedValue.title = "title"
        subject.wrappedValue.amount = 3

        XCTAssertEqual(recorder.valuesReadInOnChange, ["0"])
    }

    func testNestedKeyPathIsTrackedAsOneField() {
        let subject = ManagedState(wrappedValue: FieldModel())
        let recorder = ObservationRecorder { subject[\.trip.title] }

        subject.wrappedValue.trip.seats = 2
        subject.wrappedValue.title = "title"
        subject.wrappedValue.trip.title = "trip"

        XCTAssertEqual(recorder.valuesReadInOnChange, [""])
        XCTAssertEqual(subject[\.trip.title], "trip")
    }

    func testNestedSwiftUIBindingTracksItsFirstField() {
        let subject = ManagedState(wrappedValue: FieldModel())
        let recorder = ObservationRecorder { subject.trip.title.wrappedValue }

        subject.wrappedValue.title = "title"
        subject.wrappedValue.trip.seats = 2

        XCTAssertEqual(recorder.valuesReadInOnChange, [""])
    }

    func testNonEquatableFieldReaderTracksWholeValue() {
        let readers: [(name: String, read: (ManagedState<FieldModel>) -> String)] = [
            (name: "SwiftUI binding", read: { subject in
                return subject.payload.text.wrappedValue
            }),
            (name: "subscript", read: { subject in
                return subject[\.payload].text
            })
        ]

        for reader in readers {
            let subject = ManagedState(wrappedValue: FieldModel())
            let recorder = ObservationRecorder { reader.read(subject) }

            subject.wrappedValue.amount = 1
            subject.wrappedValue.payload.text = "text"

            XCTAssertEqual(recorder.valuesReadInOnChange, ["", ""], reader.name)
        }
    }

    func testWithLockChangingTwoFieldsNotifiesEachReaderOnce() {
        let subject = ManagedState(wrappedValue: FieldModel())
        let amountRecorder = ObservationRecorder { subject[\.amount] }
        let titleRecorder = ObservationRecorder { subject[\.title] }
        let tripTitleRecorder = ObservationRecorder { subject[\.trip.title] }
        let wholeRecorder = ObservationRecorder { subject.wrappedValue }

        subject.withLock { value in
            value.amount = 1
            value.title = "title"
        }

        XCTAssertEqual(amountRecorder.valuesReadInOnChange, [0])
        XCTAssertEqual(titleRecorder.valuesReadInOnChange, [""])
        XCTAssertEqual(tripTitleRecorder.valuesReadInOnChange, [])
        XCTAssertEqual(wholeRecorder.valuesReadInOnChange, [FieldModel()])
    }

    func testWithLockChangingTwoFieldsCallsOnChangeOfTheirReaderOnce() {
        let subject = ManagedState(wrappedValue: FieldModel())
        let observation = OneTimeObservation {
            _ = subject[\.amount]
            _ = subject[\.title]
        }

        subject.withLock { value in
            value.amount = 1
            value.title = "title"
        }

        XCTAssertEqual(observation.onChangeCallCount, 1)
    }

    func testEqualWriteNotifiesNoReader() {
        let subject = ManagedState(wrappedValue: FieldModel(amount: 1, title: "title"))
        let amountRecorder = ObservationRecorder { subject[\.amount] }
        let tripTitleRecorder = ObservationRecorder { subject[\.trip.title] }
        let payloadRecorder = ObservationRecorder { subject[\.payload].text }
        let wholeRecorder = ObservationRecorder { subject.wrappedValue }

        subject.wrappedValue.amount = 1
        subject.wrappedValue = FieldModel(amount: 1, title: "title")
        subject.withLock { value in
            value.trip.title = ""
        }

        XCTAssertEqual(amountRecorder.valuesReadInOnChange, [])
        XCTAssertEqual(tripTitleRecorder.valuesReadInOnChange, [])
        XCTAssertEqual(payloadRecorder.valuesReadInOnChange, [])
        XCTAssertEqual(wholeRecorder.valuesReadInOnChange, [])
    }

    func testFieldReaderGetsFinalResultOfRules() {
        let subject = ManagedState(wrappedValue: RuledModel())
        let doubledRecorder = ObservationRecorder { subject[\.doubled] }
        let summaryRecorder = ObservationRecorder { subject[\.summary] }
        let isLargeRecorder = ObservationRecorder { subject[\.isLarge] }

        subject.wrappedValue.amount = 1

        XCTAssertEqual(doubledRecorder.valuesReadInOnChange, [0])
        XCTAssertEqual(summaryRecorder.valuesReadInOnChange, ["0 x 2 = 0"])
        XCTAssertEqual(isLargeRecorder.valuesReadInOnChange, [])
        XCTAssertEqual(subject.wrappedValue, RuledModel(amount: 1, doubled: 2, isLarge: false, summary: "1 x 2 = 2"))
    }

    func testObservableViewModelTracksFieldThroughProjectedValue() {
        let viewModel = FieldViewModel()
        let titleRecorder = ObservationRecorder { viewModel.$state[\.title] }
        let amountRecorder = ObservationRecorder { viewModel.$state[\.amount] }

        viewModel.rename(to: "renamed")

        XCTAssertEqual(titleRecorder.valuesReadInOnChange, [""])
        XCTAssertEqual(amountRecorder.valuesReadInOnChange, [])
        XCTAssertEqual(viewModel.state, FieldModel(title: "renamed"))
    }

    func testSwiftUIBindingTracksAndWritesOneField() {
        let subject = ManagedState(wrappedValue: FieldModel())
        let title = subject.title
        let recorder = ObservationRecorder { title.wrappedValue }

        subject.wrappedValue.amount = 1
        title.wrappedValue = "title"

        XCTAssertEqual(recorder.valuesReadInOnChange, [""])
        XCTAssertEqual(subject.wrappedValue, FieldModel(amount: 1, title: "title"))
    }

    func testStateWithTrackedFieldsIsReleased() {
        weak var weakSubject: ManagedState<FieldModel>?

        autoreleasepool {
            let subject = ManagedState(wrappedValue: FieldModel())
            weakSubject = subject
            let observation = OneTimeObservation {
                _ = subject[\.trip.title]
                _ = subject[\.amount]
            }

            subject.wrappedValue.trip.title = "trip"

            XCTAssertEqual(observation.onChangeCallCount, 1)
        }

        XCTAssertNil(weakSubject)
    }

    func testConcurrentFieldReadsAndWritesKeepEveryWrite() {
        let subject = ManagedState(wrappedValue: FieldModel())
        let iterations = 200

        DispatchQueue.concurrentPerform(iterations: iterations) { index in
            switch index % 4 {
            case 0:
                _ = subject[\.title]
            case 1:
                _ = subject[\.trip.title]
            case 2:
                _ = subject[\.amountText]
            default:
                _ = subject[\.trip.seats]
            }

            subject.withLock { value in
                value.amount += 1
            }
        }

        XCTAssertEqual(subject[\.amount], iterations)
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

private struct FieldModel: BehavioralStateContract {
    var amount: Int = 0
    var title: String = ""
    var trip: Trip = .init()
    var payload: Payload = .init()

    var amountText: String {
        return "\(amount)"
    }

    static func ==(lhs: Self, rhs: Self) -> Bool {
        return lhs.amount == rhs.amount
            && lhs.title == rhs.title
            && lhs.trip == rhs.trip
            && lhs.payload.text == rhs.payload.text
    }

    mutating func applyRules() {}

    @SubscriptionBuilder
    static func applyBindingRules(to state: RulesPublisher) -> [AnyCancellable] {}

    @AnyTokenBuilder<Any>
    static func applyAnyRules(to state: UIBinding<Self>) -> [Any] {}
}

private struct Trip: Equatable {
    var title: String = ""
    var seats: Int = 0
}

private struct Payload {
    var text: String = ""
}

@available(iOS 17, macOS 14, tvOS 17, watchOS 10, visionOS 1, *)
@Observable
private final class FieldViewModel {
    @ObservationIgnored
    @ManagedState
    private(set) var state = FieldModel()

    func rename(to title: String) {
        state.title = title
    }
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
private final class ConformingViewModel: Observable {
    @ManagedState
    private(set) var viewState = ObservedModel()

    func rename(to title: String) {
        viewState.title = title
    }
}
