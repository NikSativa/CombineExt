import Foundation
import Observation

@available(iOS 17, macOS 14, tvOS 17, watchOS 10, visionOS 1, *)
final class ObservationRecorder<Value>: @unchecked Sendable {
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
