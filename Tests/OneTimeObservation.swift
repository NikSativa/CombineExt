import Foundation
import Observation

@available(iOS 17, macOS 14, tvOS 17, watchOS 10, visionOS 1, *)
final class OneTimeObservation: @unchecked Sendable {
    private let lock = NSLock()
    private var recordedCallCount = 0

    var onChangeCallCount: Int {
        return lock.withLock {
            return recordedCallCount
        }
    }

    init(_ read: () -> Void) {
        withObservationTracking {
            read()
        } onChange: { [self] in
            lock.withLock {
                recordedCallCount += 1
            }
        }
    }
}
