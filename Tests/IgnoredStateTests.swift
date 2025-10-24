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

    func test_IgnoredStateInStructs() {
        struct TestModel: Equatable, Hashable {
            var title: String
            @IgnoredState
            var cache: Data
            @IgnoredState
            var timer: Timer?

            init(title: String, cache: Data = Data(), timer: Timer? = nil) {
                self.title = title
                self._cache = IgnoredState(wrappedValue: cache)
                self._timer = IgnoredState(wrappedValue: timer)
            }
        }

        // Test that different cache values don't affect equality
        let model1 = TestModel(title: "Hello", cache: Data("cache1".utf8))
        let model2 = TestModel(title: "Hello", cache: Data("cache2".utf8))
        XCTAssertEqual(model1, model2) // Should be equal despite different cache

        // Test that different timer values don't affect equality
        let model3 = TestModel(title: "Hello", timer: Timer())
        let model4 = TestModel(title: "Hello", timer: nil)
        XCTAssertEqual(model3, model4) // Should be equal despite different timer

        // Test that title changes DO affect equality
        let model5 = TestModel(title: "World", cache: Data("cache1".utf8))
        XCTAssertNotEqual(model1, model5) // Should be different due to title

        // Test hashing behavior
        let set = Set([model1, model2, model3, model4])
        XCTAssertEqual(set.count, 1) // All should be considered the same due to ignored properties

        // Test with different IDs - should be different
        struct TestModelWithIDs: Equatable, Hashable {
            var title: String
            @IgnoredState
            var cache1: Data
            @IgnoredState
            var cache2: Data

            init(title: String, cache1: Data = Data(), cache2: Data = Data()) {
                self.title = title
                self._cache1 = IgnoredState(wrappedValue: cache1, id: 1)
                self._cache2 = IgnoredState(wrappedValue: cache2, id: 2)
            }
        }

        let modelWithIDs1 = TestModelWithIDs(title: "Hello", cache1: Data("cache1".utf8), cache2: Data("cache2".utf8))
        let modelWithIDs2 = TestModelWithIDs(title: "Hello", cache1: Data("different".utf8), cache2: Data("also_different".utf8))
        XCTAssertEqual(modelWithIDs1, modelWithIDs2) // Should be equal despite different cache values

        let setWithIDs = Set([modelWithIDs1, modelWithIDs2])
        XCTAssertEqual(setWithIDs.count, 1) // Should be considered the same
    }

    func test_IgnoredStateWithDifferentIDs() {
        struct TestModel: Equatable, Hashable {
            var title: String
            @IgnoredState
            var cache1: Data
            @IgnoredState
            var cache2: Data
            @IgnoredState
            var cache3: Data // No ID

            init(title: String, cache1: Data = Data(), cache2: Data = Data(), cache3: Data = Data()) {
                self.title = title
                self._cache1 = IgnoredState(wrappedValue: cache1, id: 1)
                self._cache2 = IgnoredState(wrappedValue: cache2, id: 2)
                self._cache3 = IgnoredState(wrappedValue: cache3)
            }
        }

        let model1 = TestModel(title: "Hello", cache1: Data("cache1".utf8), cache2: Data("cache2".utf8), cache3: Data("cache3".utf8))
        let model2 = TestModel(title: "Hello", cache1: Data("different1".utf8), cache2: Data("different2".utf8), cache3: Data("different3".utf8))

        // Should be equal because all ignored properties are ignored
        XCTAssertEqual(model1, model2)

        let set = Set([model1, model2])
        XCTAssertEqual(set.count, 1) // Should be considered the same
    }

    func test_IgnoredStateBehavior() {
        // Test that IgnoredState truly ignores values in equality and hashing
        struct TestModel: Equatable, Hashable {
            var name: String
            @IgnoredState
            var cache: String
            @IgnoredState
            var timestamp: Date

            init(name: String, cache: String = "", timestamp: Date = Date()) {
                self.name = name
                self._cache = IgnoredState(wrappedValue: cache)
                self._timestamp = IgnoredState(wrappedValue: timestamp)
            }
        }

        let now = Date()
        let later = now.addingTimeInterval(1000)

        // Different cache and timestamp values should NOT affect equality
        let model1 = TestModel(name: "Alice", cache: "cache1", timestamp: now)
        let model2 = TestModel(name: "Alice", cache: "completely_different_cache", timestamp: later)

        XCTAssertEqual(model1, model2) // Should be equal despite different ignored values

        // Different name SHOULD affect equality
        let model3 = TestModel(name: "Bob", cache: "cache1", timestamp: now)
        XCTAssertNotEqual(model1, model3) // Should be different due to name

        // Test hashing - models with same name but different ignored values should hash the same
        let set = Set([model1, model2, model3])
        XCTAssertEqual(set.count, 2) // model1 and model2 should be considered the same, model3 different

        // Test that we can still access the ignored values
        XCTAssertEqual(model1.cache, "cache1")
        XCTAssertEqual(model2.cache, "completely_different_cache")
        XCTAssertEqual(model1.timestamp, now)
        XCTAssertEqual(model2.timestamp, later)
    }

    func test_DynamicCallNoArguments() {
        // Test dynamicallyCall with no arguments
        @IgnoredState
        var closure: () -> String = { "Hello World" }

        let result = closure()
        XCTAssertEqual(result, "Hello World")

        // Test with counter closure
        var count = 0
        @IgnoredState
        var counter: () -> Int = {
            count += 1
            return count
        }

        XCTAssertEqual(counter(), 1)
        XCTAssertEqual(counter(), 2)
        XCTAssertEqual(counter(), 3)
    }

    func test_DynamicCallSingleArgument() {
        // Test dynamicallyCall with single argument
        @IgnoredState
        var formatter: (Int) -> String = { "Number: \($0)" }

        let result1 = formatter(42)
        XCTAssertEqual(result1, "Number: 42")

        let result2 = formatter(100)
        XCTAssertEqual(result2, "Number: 100")

        // Test with currency formatter
        @IgnoredState
        var currencyFormatter: (Double) -> String = { value in
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
        }

        let currency = currencyFormatter(99.99)
        XCTAssertTrue(currency.contains("99.99") || currency.contains("$99.99"))
    }

    func test_DynamicCallTwoArguments() {
        // Test dynamicallyCall with two arguments
        @IgnoredState
        var combiner: (String, Int) -> String = { text, number in "\(text)-\(number)" }

        let result1 = combiner("Hello", 42)
        XCTAssertEqual(result1, "Hello-42")

        let result2 = combiner("World", 100)
        XCTAssertEqual(result2, "World-100")

        // Test with calculator
        @IgnoredState
        var calculator: (Double, Double) -> Double = { $0 + $1 }

        let sum = calculator(3.14, 2.86)
        XCTAssertEqual(sum, 6.0, accuracy: 0.001)
    }

    func test_DynamicCallThreeArguments() {
        // Test dynamicallyCall with three arguments
        @IgnoredState
        var formatter: (String, Int, Bool) -> String = { name, age, isActive in
            "\(name) (\(age)) - \(isActive ? "Active" : "Inactive")"
        }

        let result1 = formatter("Alice", 30, true)
        XCTAssertEqual(result1, "Alice (30) - Active")

        let result2 = formatter("Bob", 25, false)
        XCTAssertEqual(result2, "Bob (25) - Inactive")

        // Test with math operation
        @IgnoredState
        var mathOp: (Int, Int, Int) -> Int = { $0 + $1 + $2 }

        let result = mathOp(1, 2, 3)
        XCTAssertEqual(result, 6)
    }
}
