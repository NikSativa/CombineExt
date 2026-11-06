import CombineExt
import Foundation
import Observation
import SwiftUI
import XCTest

@available(iOS 17, macOS 14, tvOS 17, watchOS 10, visionOS 1, *)
final class UIStateObservationTests: XCTestCase {
    func testWholeValueReaderIsNotifiedForEachChangeWithOldValue() {
        let state = UIState(wrappedValue: CounterState())
        let recorder = ObservationRecorder { state.wrappedValue }

        state.wrappedValue.counter = 1
        state.wrappedValue.counter = 1
        state.wrappedValue.title = "title"

        XCTAssertEqual(recorder.valuesReadInOnChange, [CounterState(), CounterState(counter: 1)])
    }

    func testFieldReaderIsNotifiedOnlyForChangeOfItsField() {
        let state = UIState(wrappedValue: CounterState())
        let recorder = ObservationRecorder { state[\.counter] }

        state.wrappedValue.title = "title"
        state.wrappedValue.trip.seats = 2
        state.wrappedValue.counter = 5
        state.wrappedValue.title = "other"

        XCTAssertEqual(recorder.valuesReadInOnChange, [0])
    }

    func testReadOnlyFieldReaderIsNotifiedOnlyWhenItsValueChanges() {
        let state = UIState(wrappedValue: CounterState())
        let recorder = ObservationRecorder { state[\.counterText] }

        state.wrappedValue.title = "title"
        state.wrappedValue.counter = 3

        XCTAssertEqual(recorder.valuesReadInOnChange, ["0"])
    }

    func testNestedKeyPathIsTrackedAsOneField() {
        let state = UIState(wrappedValue: CounterState())
        let recorder = ObservationRecorder { state[\.trip.title] }

        state.wrappedValue.trip.seats = 2
        state.wrappedValue.trip.title = "trip"

        XCTAssertEqual(recorder.valuesReadInOnChange, [""])
    }

    func testWithLockChangingTwoFieldsCallsOnChangeOnce() {
        let state = UIState(wrappedValue: CounterState())
        let observation = OneTimeObservation {
            _ = state[\.counter]
            _ = state[\.title]
            _ = state.wrappedValue
        }

        state.withLock { value in
            value.counter = 1
            value.title = "title"
        }

        XCTAssertEqual(observation.onChangeCallCount, 1)
        XCTAssertEqual(state.wrappedValue, CounterState(counter: 1, title: "title"))
    }

    func testEqualWriteNotifiesNoReader() {
        let state = UIState(wrappedValue: CounterState(counter: 1))
        let fieldRecorder = ObservationRecorder { state[\.counter] }
        let wholeRecorder = ObservationRecorder { state.wrappedValue }

        state.wrappedValue.counter = 1
        state.wrappedValue = CounterState(counter: 1)
        state.withLock { value in
            value.title = ""
        }

        XCTAssertEqual(fieldRecorder.valuesReadInOnChange, [])
        XCTAssertEqual(wholeRecorder.valuesReadInOnChange, [])
    }

    func testSwiftUIBindingTracksAndWritesOneField() {
        let state = UIState(wrappedValue: CounterState())
        let title: Binding<String> = state.title
        let recorder = ObservationRecorder { title.wrappedValue }

        state.wrappedValue.counter = 1
        title.wrappedValue = "title"

        XCTAssertEqual(recorder.valuesReadInOnChange, [""])
        XCTAssertEqual(state.wrappedValue, CounterState(counter: 1, title: "title"))
    }

    func testUIBindingReadTracksWholeValue() {
        let state = UIState(wrappedValue: CounterState())
        let title: UIBinding<String> = state.ui.title
        let recorder = ObservationRecorder { title.wrappedValue }

        state.wrappedValue.counter = 1

        XCTAssertEqual(recorder.valuesReadInOnChange, [""])
    }

    func testObservableViewModelTracksFieldThroughProjectedValue() {
        let viewModel = CounterViewModel()
        let counterRecorder = ObservationRecorder { viewModel.$state[\.counter] }
        let titleRecorder = ObservationRecorder { viewModel.$state[\.title] }

        viewModel.increment()

        XCTAssertEqual(counterRecorder.valuesReadInOnChange, [0])
        XCTAssertEqual(titleRecorder.valuesReadInOnChange, [])
        XCTAssertEqual(viewModel.state, CounterState(counter: 1))
    }

    func testStateWithTrackedFieldsIsReleased() {
        weak var weakState: UIState<CounterState>?

        autoreleasepool {
            let state = UIState(wrappedValue: CounterState())
            weakState = state
            let observation = OneTimeObservation {
                _ = state[\.trip.title]
                _ = state.wrappedValue
            }

            state.wrappedValue.trip.title = "trip"

            XCTAssertEqual(observation.onChangeCallCount, 1)
        }

        XCTAssertNil(weakState)
    }

    func testConcurrentFieldReadsAndWritesKeepEveryWrite() {
        let state = UIState(wrappedValue: CounterState())
        let iterations = 200

        DispatchQueue.concurrentPerform(iterations: iterations) { index in
            if index.isMultiple(of: 2) {
                _ = state[\.title]
            } else {
                _ = state[\.counterText]
            }

            state.withLock { value in
                value.counter += 1
            }
        }

        XCTAssertEqual(state[\.counter], iterations)
    }
}

private struct CounterState: Equatable {
    var counter: Int = 0
    var title: String = ""
    var trip: Trip = .init()

    var counterText: String {
        return "\(counter)"
    }
}

private struct Trip: Equatable {
    var title: String = ""
    var seats: Int = 0
}

@available(iOS 17, macOS 14, tvOS 17, watchOS 10, visionOS 1, *)
@Observable
private final class CounterViewModel {
    @ObservationIgnored
    @UIState
    private(set) var state = CounterState()

    func increment() {
        state.counter += 1
    }
}
