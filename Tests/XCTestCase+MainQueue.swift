import Foundation
import XCTest

extension XCTestCase {
    func waitForMainQueue() {
        let mainQueueReached = expectation(description: "the main queue runs the work that the test enqueued before")
        DispatchQueue.main.async {
            mainQueueReached.fulfill()
        }
        wait(for: [mainQueueReached], timeout: 10)
    }
}
