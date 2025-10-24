import CombineExt
import Foundation
import XCTest

final class ResultBuilderTests: XCTestCase {
    // MARK: - SubscriptionBuilder Tests

    func testSubscriptionBuilderBuildBlock() {
        let cancellable1 = AnyCancellable {}
        let cancellable2 = AnyCancellable {}
        let cancellable3 = AnyCancellable {}

        let result = SubscriptionBuilder.buildBlock([cancellable1, cancellable2],
                                                    [cancellable3])

        XCTAssertEqual(result.count, 3)
    }

    func testSubscriptionBuilderBuildOptional() {
        let cancellable1 = AnyCancellable {}
        let cancellable2 = AnyCancellable {}

        // Test with non-nil array
        let result1 = SubscriptionBuilder.buildOptional([cancellable1, cancellable2])
        XCTAssertEqual(result1.count, 2)

        // Test with nil array
        let result2 = SubscriptionBuilder.buildOptional(nil)
        XCTAssertEqual(result2.count, 0)
    }

    func testSubscriptionBuilderBuildEither() {
        let cancellable1 = AnyCancellable {}
        let cancellable2 = AnyCancellable {}

        // Test first branch
        let result1 = SubscriptionBuilder.buildEither(first: [cancellable1, cancellable2])
        XCTAssertEqual(result1.count, 2)

        // Test second branch
        let result2 = SubscriptionBuilder.buildEither(second: [cancellable1, cancellable2])
        XCTAssertEqual(result2.count, 2)
    }

    func testSubscriptionBuilderBuildArray() {
        let cancellable1 = AnyCancellable {}
        let cancellable2 = AnyCancellable {}
        let cancellable3 = AnyCancellable {}

        let result = SubscriptionBuilder.buildArray([
            [cancellable1],
            [cancellable2, cancellable3]
        ])

        XCTAssertEqual(result.count, 3)
    }

    func testSubscriptionBuilderBuildLimitedAvailability() {
        let cancellable1 = AnyCancellable {}
        let cancellable2 = AnyCancellable {}

        let result = SubscriptionBuilder.buildLimitedAvailability([cancellable1, cancellable2])
        XCTAssertEqual(result.count, 2)
    }

    func testSubscriptionBuilderBuildFinalResult() {
        let cancellable1 = AnyCancellable {}
        let cancellable2 = AnyCancellable {}

        let result = SubscriptionBuilder.buildBlock([cancellable1, cancellable2])
        XCTAssertEqual(result.count, 2)
    }

    func testSubscriptionBuilderWithConditionalLogic() {
        let shouldInclude = Bool.random()
        let cancellable1 = AnyCancellable {}
        let cancellable2 = AnyCancellable {}

        let result: [AnyCancellable] = SubscriptionBuilder.buildBlock([cancellable1],
                                                                      shouldInclude ? [cancellable2] : [])

        XCTAssertEqual(result.count, shouldInclude ? 2 : 1)
    }

    func testSubscriptionBuilderWithIfElse() {
        let condition = Bool.random()
        let cancellable1 = AnyCancellable {}
        let cancellable2 = AnyCancellable {}

        let result: [AnyCancellable] = SubscriptionBuilder.buildBlock(
            condition ? [cancellable1] : [cancellable2]
        )

        XCTAssertEqual(result.count, 1)
        if condition {
            XCTAssertTrue(result.contains(cancellable1))
        } else {
            XCTAssertTrue(result.contains(cancellable2))
        }
    }

    // MARK: - AnyTokenBuilder Tests

    func testAnyTokenBuilderBuildBlock() {
        let token1 = "token1"
        let token2 = "token2"
        let token3 = "token3"

        let result = AnyTokenBuilder<String>.buildBlock([token1, token2],
                                                        [token3])

        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result, [token1, token2, token3])
    }

    func testAnyTokenBuilderBuildOptional() {
        let token1 = "token1"
        let token2 = "token2"

        // Test with non-nil array
        let result1 = AnyTokenBuilder<String>.buildOptional([token1, token2])
        XCTAssertEqual(result1.count, 2)
        XCTAssertEqual(result1, [token1, token2])

        // Test with nil array
        let result2 = AnyTokenBuilder<String>.buildOptional(nil)
        XCTAssertEqual(result2.count, 0)
    }

    func testAnyTokenBuilderBuildEither() {
        let token1 = "token1"
        let token2 = "token2"

        // Test first branch
        let result1 = AnyTokenBuilder<String>.buildEither(first: [token1, token2])
        XCTAssertEqual(result1.count, 2)
        XCTAssertEqual(result1, [token1, token2])

        // Test second branch
        let result2 = AnyTokenBuilder<String>.buildEither(second: [token1, token2])
        XCTAssertEqual(result2.count, 2)
        XCTAssertEqual(result2, [token1, token2])
    }

    func testAnyTokenBuilderBuildArray() {
        let token1 = "token1"
        let token2 = "token2"
        let token3 = "token3"

        let result = AnyTokenBuilder<String>.buildArray([
            [token1],
            [token2, token3]
        ])

        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result, [token1, token2, token3])
    }

    func testAnyTokenBuilderBuildLimitedAvailability() {
        let token1 = "token1"
        let token2 = "token2"

        let result = AnyTokenBuilder<String>.buildLimitedAvailability([token1, token2])
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result, [token1, token2])
    }

    func testAnyTokenBuilderBuildFinalResult() {
        let token1 = "token1"
        let token2 = "token2"

        let result = AnyTokenBuilder<String>.buildBlock([token1, token2])
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result, [token1, token2])
    }

    func testAnyTokenBuilderWithConditionalLogic() {
        let shouldInclude = Bool.random()
        let token1 = "token1"
        let token2 = "token2"

        let result: [String] = AnyTokenBuilder.buildBlock([token1],
                                                          shouldInclude ? [token2] : [])

        XCTAssertEqual(result.count, shouldInclude ? 2 : 1)
        if shouldInclude {
            XCTAssertEqual(result, [token1, token2])
        } else {
            XCTAssertEqual(result, [token1])
        }
    }

    func testAnyTokenBuilderWithIfElse() {
        let condition = Bool.random()
        let token1 = "token1"
        let token2 = "token2"

        let result: [String] = AnyTokenBuilder.buildBlock(
            condition ? [token1] : [token2]
        )

        XCTAssertEqual(result.count, 1)
        if condition {
            XCTAssertEqual(result, [token1])
        } else {
            XCTAssertEqual(result, [token2])
        }
    }

    func testAnyTokenBuilderWithEmptyArrays() {
        let result: [String] = AnyTokenBuilder.buildBlock([],
                                                          [],
                                                          [])

        XCTAssertEqual(result.count, 0)
    }

    func testAnyTokenBuilderWithMixedTypes() {
        // Test with different types
        let stringTokens = ["token1", "token2"]
        let intTokens = [1, 2, 3]

        let stringResult: [String] = AnyTokenBuilder.buildBlock(stringTokens)
        XCTAssertEqual(stringResult.count, 2)

        let intResult: [Int] = AnyTokenBuilder.buildBlock(intTokens)
        XCTAssertEqual(intResult.count, 3)
    }

    func testAnyTokenBuilderWithNestedArrays() {
        let token1 = "token1"
        let token2 = "token2"
        let token3 = "token3"
        let token4 = "token4"

        let result: [String] = AnyTokenBuilder.build {
            [token1, token2]
            [token3]
            [token4]
        }

        XCTAssertEqual(result.count, 4)
        XCTAssertEqual(result, [token1, token2, token3, token4])
    }

    func testAnyTokenBuilderWithComplexConditional() {
        let condition1 = true
        let condition2 = false
        let token1 = "token1"
        let token2 = "token2"
        let token3 = "token3"
        let token4 = "token4"

        let result: [String] = AnyTokenBuilder.build {
            [token1]

            if condition1 {
                [token2]
            }

            if condition2 {
                [token3]
            } else {
                [token4]
            }
        }

        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result, [token1, token2, token4])
    }

    // MARK: - Additional SubscriptionBuilder Tests

    func testSubscriptionBuilderWithEmptyArrays() {
        let result: [AnyCancellable] = SubscriptionBuilder.buildBlock([],
                                                                      [],
                                                                      [])

        XCTAssertEqual(result.count, 0)
    }

    func testSubscriptionBuilderWithMixedTypes() {
        let cancellable1 = AnyCancellable {}
        let cancellable2 = AnyCancellable {}
        let cancellable3 = AnyCancellable {}

        let result: [AnyCancellable] = SubscriptionBuilder.buildBlock([cancellable1],
                                                                      [cancellable2, cancellable3])

        XCTAssertEqual(result.count, 3)
        XCTAssertTrue(result.contains(cancellable1))
        XCTAssertTrue(result.contains(cancellable2))
        XCTAssertTrue(result.contains(cancellable3))
    }

    func testSubscriptionBuilderWithNestedArrays() {
        let cancellable1 = AnyCancellable {}
        let cancellable2 = AnyCancellable {}
        let cancellable3 = AnyCancellable {}
        let cancellable4 = AnyCancellable {}

        let result: [AnyCancellable] = SubscriptionBuilder.buildBlock([cancellable1, cancellable2],
                                                                      [cancellable3],
                                                                      [cancellable4])

        XCTAssertEqual(result.count, 4)
        XCTAssertTrue(result.contains(cancellable1))
        XCTAssertTrue(result.contains(cancellable2))
        XCTAssertTrue(result.contains(cancellable3))
        XCTAssertTrue(result.contains(cancellable4))
    }

    // MARK: - Additional AnyTokenBuilder Tests

    func testAnyTokenBuilderWithEmptyArraysAdditional() {
        let result: [String] = AnyTokenBuilder.buildBlock([],
                                                          [],
                                                          [])

        XCTAssertEqual(result.count, 0)
    }

    func testAnyTokenBuilderWithMixedTypesAdditional() {
        let stringTokens = ["token1", "token2"]
        let intTokens = [1, 2, 3]

        let stringResult: [String] = AnyTokenBuilder.buildBlock(stringTokens)
        XCTAssertEqual(stringResult.count, 2)

        let intResult: [Int] = AnyTokenBuilder.buildBlock(intTokens)
        XCTAssertEqual(intResult.count, 3)
    }

    func testAnyTokenBuilderWithNestedArraysAdditional() {
        let token1 = "token1"
        let token2 = "token2"
        let token3 = "token3"
        let token4 = "token4"

        let result: [String] = AnyTokenBuilder.build {
            [token1, token2]
            [token3]
            [token4]
        }

        XCTAssertEqual(result.count, 4)
        XCTAssertEqual(result, [token1, token2, token3, token4])
    }

    // MARK: - Edge Cases and Error Scenarios

    func testSubscriptionBuilderWithNilValues() {
        let cancellable1 = AnyCancellable {}
        let cancellable2 = AnyCancellable {}

        // Test with nil optional
        let result1: [AnyCancellable] = SubscriptionBuilder.buildOptional(nil)
        XCTAssertEqual(result1.count, 0)

        // Test with non-nil optional
        let result2: [AnyCancellable] = SubscriptionBuilder.buildOptional([cancellable1, cancellable2])
        XCTAssertEqual(result2.count, 2)
    }

    func testAnyTokenBuilderWithNilValues() {
        let token1 = "token1"
        let token2 = "token2"

        // Test with nil optional
        let result1: [String] = AnyTokenBuilder<String>.buildOptional(nil)
        XCTAssertEqual(result1.count, 0)

        // Test with non-nil optional
        let result2: [String] = AnyTokenBuilder<String>.buildOptional([token1, token2])
        XCTAssertEqual(result2.count, 2)
    }

    func testSubscriptionBuilderWithSingleElement() {
        let cancellable = AnyCancellable {}

        let result: [AnyCancellable] = SubscriptionBuilder.buildBlock([cancellable])
        XCTAssertEqual(result.count, 1)
        XCTAssertTrue(result.contains(cancellable))
    }

    func testAnyTokenBuilderWithSingleElement() {
        let token = "token"

        let result: [String] = AnyTokenBuilder.buildBlock([token])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result, [token])
    }

    func testSubscriptionBuilderWithLargeArrays() {
        let cancellables = (0..<100).map { _ in AnyCancellable {} }

        let result: [AnyCancellable] = SubscriptionBuilder.buildBlock(cancellables)
        XCTAssertEqual(result.count, 100)
    }

    func testAnyTokenBuilderWithLargeArrays() {
        let tokens = (0..<100).map { "token\($0)" }

        let result: [String] = AnyTokenBuilder.buildBlock(tokens)
        XCTAssertEqual(result.count, 100)
        XCTAssertEqual(result, tokens)
    }

    // MARK: - Performance Tests

    func testSubscriptionBuilderPerformance() {
        let cancellables = (0..<1000).map { _ in AnyCancellable {} }

        measure {
            let result: [AnyCancellable] = SubscriptionBuilder.buildBlock(cancellables)
            XCTAssertEqual(result.count, 1000)
        }
    }

    func testAnyTokenBuilderPerformance() {
        let tokens = (0..<1000).map { "token\($0)" }

        measure {
            let result: [String] = AnyTokenBuilder.buildBlock(tokens)
            XCTAssertEqual(result.count, 1000)
        }
    }
}
