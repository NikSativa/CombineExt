import Combine
import CombineExt
import XCTest

final class IgnoredStateTests: XCTestCase {
    func test_equatable() {
        var a = IgnoredState(wrappedValue: 0)
        var b = IgnoredState(wrappedValue: 1)
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.hashValue, b.hashValue)

        a = IgnoredState(wrappedValue: 0, id: 1)
        b = IgnoredState(wrappedValue: 1, id: 2)
        XCTAssertNotEqual(a, b)
        XCTAssertNotEqual(a.hashValue, b.hashValue)

        a = IgnoredState(wrappedValue: 0, id: 1)
        b = IgnoredState(wrappedValue: 1, id: 1)
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.hashValue, b.hashValue)

        a = IgnoredState(wrappedValue: 1, id: 1)
        b = IgnoredState(wrappedValue: 1, id: 1)
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.hashValue, b.hashValue)

        a = IgnoredState(wrappedValue: 0, id: 1)
        b = IgnoredState(wrappedValue: 1)
        XCTAssertNotEqual(a, b)
        XCTAssertNotEqual(a.hashValue, b.hashValue)
    }

    func test_Hashable() {
        var a = IgnoredState(wrappedValue: 0)
        var b = IgnoredState(wrappedValue: 1)
        var c = Set([a, b])
        XCTAssertEqual(c.count, 1)
        XCTAssertEqual(c.first?.wrappedValue, a.wrappedValue)

        var d = c.insert(b)
        XCTAssertFalse(d.inserted)
        XCTAssertEqual(d.memberAfterInsert.wrappedValue, a.wrappedValue)

        a = IgnoredState(wrappedValue: 0)
        b = IgnoredState(wrappedValue: 1, id: 1)
        c = Set([a, b])
        XCTAssertEqual(c.count, 2)
        XCTAssertTrue(c.contains(a) && c.contains(b))

        c = Set([a])
        d = c.insert(b)
        XCTAssertTrue(d.inserted)
        XCTAssertTrue(c.contains(a) && c.contains(b))

        a = IgnoredState(wrappedValue: 0, id: 1)
        b = IgnoredState(wrappedValue: 1, id: 1)
        c = Set([a, b])
        XCTAssertEqual(c.count, 1)
        XCTAssertEqual(c.first?.wrappedValue, a.wrappedValue)

        d = c.insert(b)
        XCTAssertEqual(d.inserted, false)
        XCTAssertEqual(d.memberAfterInsert.wrappedValue, a.wrappedValue)
    }
}
