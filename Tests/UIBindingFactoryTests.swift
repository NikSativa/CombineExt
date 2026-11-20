import Combine
import CombineExt
import XCTest

final class UIBindingFactoryTests: XCTestCase {
    private var cancellables: Set<AnyCancellable> = []

    func testPlaceholderDoesNotReadItsValueWhenItIsCreated() {
        @UIBinding(.placeholder)
        var title: String
        _title = .constant("Title")

        XCTAssertEqual(title, "Title")
    }

    func testSubscriptionToPlaceholderDoesNotReadItsValue() {
        let placeholder = UIBinding<String>(.placeholder)
        var emissionCount = 0
        placeholder
            .sink { (_: DiffedValue<String>) in
                emissionCount += 1
            }
            .store(in: &cancellables)

        XCTAssertEqual(emissionCount, 1)
    }

    func testSubscriptionToAFieldOfPlaceholderDoesNotReadItsValue() {
        let placeholder = UIBinding<Title>(.placeholder)
        var emissionCount = 0
        placeholder.text
            .sink { (_: DiffedValue<String>) in
                emissionCount += 1
            }
            .store(in: &cancellables)

        XCTAssertEqual(emissionCount, 1)
    }
}

private struct Title {
    var text: String
}
