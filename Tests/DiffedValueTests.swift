import CombineExt
import XCTest

final class DiffedValueTests: XCTestCase {
    func testChangedValueIsEqualToItself() {
        let diff = DiffedValue(old: 1, get: 2, set: { _ in })

        XCTAssertEqual(diff, diff)
    }

    func testEqualityComparesBothOperands() {
        let change = DiffedValue(old: 1, get: 2, set: { _ in })
        let sameChange = DiffedValue(old: 1, get: 2, set: { _ in })
        let noChange = DiffedValue(old: 3, get: 3, set: { _ in })

        XCTAssertEqual(change, sameChange)
        XCTAssertEqual(change.hashValue, sameChange.hashValue)
        XCTAssertNotEqual(change, noChange)
    }
}
