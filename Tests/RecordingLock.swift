import Foundation

final class RecordingLock: NSLocking, @unchecked Sendable {
    private let innerLock = NSRecursiveLock()
    private var depth = 0
    private var recordedLockCount = 0
    private var recordedMaxDepth = 0

    var lockCount: Int {
        return innerLock.withLock {
            return recordedLockCount
        }
    }

    var maxDepth: Int {
        return innerLock.withLock {
            return recordedMaxDepth
        }
    }

    func lock() {
        innerLock.lock()
        depth += 1
        recordedLockCount += 1
        recordedMaxDepth = max(recordedMaxDepth, depth)
    }

    func unlock() {
        depth -= 1
        innerLock.unlock()
    }
}
