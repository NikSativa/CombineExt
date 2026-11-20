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

    func testValuesWithEqualOldAndDifferentNewValuesAtCreationAreNotEqual() {
        var list: [Int] = []
        let first = DiffedValue(old: [], get: { list }, set: { list = $0 })
        list = [1]
        let second = DiffedValue(old: [], get: { list }, set: { list = $0 })

        XCTAssertNotEqual(first, second)
        XCTAssertEqual(Set([first, second]).count, 2)
        XCTAssertEqual(first.new, [1])
    }

    func testHashOfEqualValuesDoesNotChangeWhenTheSourceChanges() {
        var list: [Int] = []
        let diff = DiffedValue(old: [], get: { list }, set: { list = $0 })
        let sameDiff = DiffedValue(old: [], get: { list }, set: { list = $0 })
        let hashBeforeChange = diff.hashValue

        list = [1]

        XCTAssertEqual(diff, sameDiff)
        XCTAssertEqual(diff.hashValue, sameDiff.hashValue)
        XCTAssertEqual(diff.hashValue, hashBeforeChange)
    }

    func testMapToKeyPathKeepsTheValueOfTheFieldAtCreation() {
        var model = ListModel()
        let diff = DiffedValue(old: model, get: { model }, set: { model = $0 }).map(keyPath: \.list)

        model.list = [1]

        XCTAssertEqual(diff, DiffedValue(old: [], get: [], set: { _ in }))
        XCTAssertEqual(diff.new, [1])
    }
}
