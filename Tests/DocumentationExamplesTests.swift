import Combine
import CombineExt
import Foundation
import XCTest
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
#if canImport(SwiftUI)
import SwiftUI
#endif

/// This file contains all code examples from the README.md documentation.
/// It ensures that all examples compile and work correctly.
@MainActor
final class DocumentationExamplesTests: XCTestCase {
    private var cancellables: Set<AnyCancellable> = []

    // MARK: - ManagedState Examples

    func testManagedStateExample() {
        struct CounterModel: BehavioralStateContract {
            var displayText: String = "0"
            var count: Int = 0
            var isOdd: Bool = false

            mutating func applyRules() {
                isOdd = count % 2 != 0
            }

            @SubscriptionBuilder
            static func applyBindingRules(to state: RulesPublisher) -> [AnyCancellable] {
                state.bindDiffed(to: \.count) { pair in
                    pair.new.displayText = "was: \(pair.old?.count ?? 0) - now: \(pair.new.count)"
                }
            }

            @AnyTokenBuilder<Any>
            static func applyAnyRules(to state: UIBinding<Self>) -> [Any] {
                []
            }
        }

        @ManagedState
        var model = CounterModel()
        $model.sink { _ in }.store(in: &cancellables)
        model.count += 1
    }

    func testManagedStateDynamicCallable() {
        struct CounterModel: BehavioralStateContract {
            var count: Int = 0
            var displayText: String = "0"

            mutating func applyRules() {}
            @SubscriptionBuilder
            static func applyBindingRules(to state: RulesPublisher) -> [AnyCancellable] { [] }
            @AnyTokenBuilder<Any>
            static func applyAnyRules(to state: UIBinding<Self>) -> [Any] { [] }
        }

        @ManagedState
        var model = CounterModel()

        let countBinding = $model(\.count)
        let displayBinding = $model(\.displayText)

        countBinding.wrappedValue = 10
        displayBinding.wrappedValue = "Updated"
    }

    // MARK: - UIState Examples

    func testUIStateExample() {
        struct ViewState: Equatable { var isOn: Bool }
        @UIState
        var state = ViewState(isOn: false)

        $state.isOn
            .sink { _ in }
            .store(in: &cancellables)

        state.isOn = true
    }

    func testUIStateDynamicCallable() {
        struct ViewState: Equatable { var isOn: Bool }
        @UIState
        var state = ViewState(isOn: false)

        let binding = $state()
        let isOnBinding = $state(\.isOn)

        isOnBinding.wrappedValue = true
        _ = binding
    }

    // MARK: - UIBinding Examples

    func testUIBindingAsPropertyWrapper() {
        #if canImport(UIKit)
        struct State: Equatable { var name: String }
        @UIState
        var state = State(name: "name")

        final class MyView: UIView {
            @UIBinding(.placeholder)
            private var name: String
            private var cancellables: Set<AnyCancellable> = []

            func configure(withName binding: UIBinding<String>) {
                _name = binding

                $name
                    .sink { _ in }
                    .store(in: &cancellables)

                $name.publisher
                    .sink { _ in }
                    .store(in: &cancellables)
            }

            func buttonTapped() {
                name = "new name"
            }
        }

        let view = MyView(frame: .zero)
        view.configure(withName: $state.name)
        view.buttonTapped()
        #endif
    }

    func testUIBindingWithConstant() {
        // Test direct usage of UIBinding.constant() (not as property wrapper)
        @UIBinding(.placeholder)
        var titleBinding: String
        _titleBinding = .constant("Read-only")

        XCTAssertEqual(titleBinding, "Read-only")

        titleBinding = "World" // Should be ignored
        XCTAssertEqual(titleBinding, "Read-only")

        $titleBinding
            .sink { _ in }
            .store(in: &cancellables)

        $titleBinding.publisher
            .sink { _ in }
            .store(in: &cancellables)
    }

    func testUIBindingWithPlaceholder() {
        #if canImport(UIKit)
        final class MyView: UIView {
            @UIBinding(.placeholder)
            private var name: String
            private var cancellables: Set<AnyCancellable> = []

            func configure(withName binding: UIBinding<String>) {
                _name = binding
            }
        }

        let view = MyView(frame: .zero)
        struct State: Equatable { var name: String }
        @UIState
        var state = State(name: "test")
        view.configure(withName: $state.name)
        #endif
    }

    func testUIBindingDirectUsage() {
        let titleBinding = UIBinding<String>.constant("Fixed Title")

        XCTAssertEqual(titleBinding.wrappedValue, "Fixed Title")

        titleBinding.wrappedValue = "New Title"
        XCTAssertEqual(titleBinding.wrappedValue, "Fixed Title")

        titleBinding
            .sink { _ in }
            .store(in: &cancellables)

        titleBinding.publisher
            .sink { _ in }
            .store(in: &cancellables)

        // SwiftUI example from documentation (for reference only, not tested)
        #if canImport(SwiftUI)
        struct ContentView: View {
            @UIBinding
            var binding: String

            var body: some View {
                Text(binding)
            }

            static var previews: some View {
                ContentView(binding: .constant("Preview Data"))
            }
        }
        #endif
    }

    func testUIBindingExpressibleByNilLiteral() {
        #if canImport(UIKit)
        /// This test demonstrates the custom extension pattern from documentation
        /// The extension is defined at file scope below
        final class MyView: UIView {
            @UIBinding(.placeholder)
            private var optionalName: String?

            override init(frame: CGRect) {
                super.init(frame: frame)
            }

            @available(*, unavailable)
            required init?(coder: NSCoder) {
                fatalError("init(coder:) has not been implemented")
            }
        }

        let view = MyView(frame: .zero)
        // Test that the binding is initialized (can't access private property directly)
        _ = view
        #endif
    }

    // MARK: - ValueSubject Examples

    func testValueSubjectExample() {
        struct Form: Equatable { var name: String }
        @ValueSubject
        var form = Form(name: "")

        $form
            .map(\.name)
            .sink { _ in }
            .store(in: &cancellables)

        form.name = "Nik"
    }

    func testValueSubjectDynamicCallable() {
        struct User: Equatable {
            var name: String = "John"
            var age: Int = 25
        }

        @ValueSubject
        var user = User()
        let binding = $user

        // Subscribe to changes
        $user
            .sink { _ in }
            .store(in: &cancellables)

        // Update values directly
        user.name = "Jane"
        user.age = 30
        _ = binding
    }

    // MARK: - IgnoredState Examples

    func testIgnoredStateExample() {
        struct DataCache: Equatable {
            static func ==(_: DataCache, _: DataCache) -> Bool { true }
        }

        struct ViewModel: Equatable {
            var title: String = "Hello"
            @IgnoredState
            var cache = DataCache()
            @IgnoredState
            var timer: Timer?
        }

        let vm1 = ViewModel()
        var vm2 = ViewModel()
        vm2.cache = DataCache()
        XCTAssertEqual(vm1, vm2)
    }

    func testIgnoredStateWithClosures() {
        @IgnoredState
        var formatter: (Double) -> String = { value in
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
        }

        let price = formatter(99.99)
        XCTAssertFalse(price.isEmpty)
    }

    func testIgnoredStateWithCustomIDs() {
        struct Model: Hashable {
            @IgnoredState(id: 1)
            var cache1 = Data()
            @IgnoredState(id: 2)
            var cache2 = Data()
        }

        let model = Model()
        _ = model.hashValue
    }

    // MARK: - DiffedValue Examples

    func testDiffedValueExample() {
        @UIState
        var counter = 0

        $counter.publisher
            .sink { diff in
                _ = "Changed from \(diff.old ?? 0) to \(diff.new)"
            }
            .store(in: &cancellables)

        counter = 5
    }

    func testDiffedValueDynamicMemberAccess() {
        struct User: Equatable { var name: String
            var age: Int
        }
        @UIState
        var user = User(name: "Alice", age: 30)

        $user.publisher
            .sink { diff in
                _ = diff.name
                _ = diff.age
            }
            .store(in: &cancellables)
    }

    // MARK: - Publisher Extensions

    func testFilterNils() {
        Just<String?>(nil)
            .filterNils()
            .sink { _ in XCTFail("Should not be called") }
            .store(in: &cancellables)

        Just("Hello")
            .filterNils()
            .sink { value in
                XCTAssertEqual(value, "Hello")
            }
            .store(in: &cancellables)
    }

    func testMapVoid() {
        let subject = PassthroughSubject<String, Never>()

        subject
            .mapVoid()
            .sink { _ in }
            .store(in: &cancellables)

        subject.send("test")
    }

    func testAdvancedBindingMethods() {
        struct Profile: Equatable {
            var name: String = ""
        }

        struct Model: BehavioralStateContract {
            var username: String = ""
            var count: Int = 0
            var profile: Profile = .init()
            var readOnlyProperty: String = ""
            var computedProperty: String = ""

            mutating func applyRules() {}

            @SubscriptionBuilder
            static func applyBindingRules(to state: RulesPublisher) -> [AnyCancellable] { [] }

            @AnyTokenBuilder<Any>
            static func applyAnyRules(to state: UIBinding<Self>) -> [Any] { [] }
        }

        @UIState
        var state = Model()

        $state.publisher
            .bind(to: \Model.username) { model in
                model.username = "updated"
            }
            .store(in: &cancellables)

        $state.publisher
            .bindDiffed(to: \Model.count) { _, diff in
                _ = "Count changed from \(diff.old ?? 0) to \(diff.new)"
            }
            .store(in: &cancellables)

        $state.publisher
            .bind(to: \Model.profile.name) { name in
                name = name.uppercased()
            }
            .store(in: &cancellables)

        $state.publisher
            .bind(to: \Model.readOnlyProperty) { value in
                _ = "Read-only property changed to: \(value)"
            }
            .store(in: &cancellables)

        $state.publisher
            .bindDiffed(to: \Model.computedProperty) { _, diff in
                _ = "Computed property changed from \(diff.old ?? "nil") to \(diff.new)"
            }
            .store(in: &cancellables)
    }

    // MARK: - Extended Combine Publishers

    func testCombineLatest5() {
        let name = PassthroughSubject<String, Never>()
        let age = PassthroughSubject<Int, Never>()
        let email = PassthroughSubject<String, Never>()
        let isActive = PassthroughSubject<Bool, Never>()
        let lastLogin = PassthroughSubject<Date, Never>()

        Publishers.CombineLatest5(name, age, email, isActive, lastLogin)
            .sink { name, age, email, isActive, lastLogin in
                _ = "User: \(name), \(age), \(email), active: \(isActive), lastLogin: \(lastLogin)"
            }
            .store(in: &cancellables)

        name.send("Test")
        age.send(25)
        email.send("test@example.com")
        isActive.send(true)
        lastLogin.send(Date())
    }

    func testZip5() {
        let step1 = PassthroughSubject<String, Never>()
        let step2 = PassthroughSubject<String, Never>()
        let step3 = PassthroughSubject<String, Never>()
        let step4 = PassthroughSubject<String, Never>()
        let step5 = PassthroughSubject<String, Never>()

        Publishers.Zip5(step1, step2, step3, step4, step5)
            .sink { step1, step2, step3, step4, step5 in
                _ = "All steps completed: \([step1, step2, step3, step4, step5])"
            }
            .store(in: &cancellables)

        step1.send("1")
        step2.send("2")
        step3.send("3")
        step4.send("4")
        step5.send("5")
    }

    // MARK: - Safe Collection Access

    func testSafeCollectionAccess() {
        @UIState
        var items = ["A", "B", "C"]

        let item = $items.safe(10, default: "Not Found")
        XCTAssertEqual(item.wrappedValue, "Not Found")

        let safeItem = $items.safe(1)
        XCTAssertEqual(safeItem.wrappedValue, "B")

        let unsafeItem = $items.unsafe(1)
        XCTAssertEqual(unsafeItem.wrappedValue, "B")

        let bindings = $items.bindingArray()
        bindings[0].wrappedValue = "Updated"
        XCTAssertEqual(items[0], "Updated")
    }

    // MARK: - Utility Functions

    func testDiffersFunction() {
        struct Person {
            let name: String
            let age: Int
        }

        let person1 = Person(name: "Alice", age: 30)
        let person2 = Person(name: "Bob", age: 25)

        let nameDiffers = differs(lhs: person1, rhs: person2, keyPath: \.name)
        XCTAssertTrue(nameDiffers)

        let ageDiffers = differs(lhs: person1, rhs: person2, keyPath: \.age)
        XCTAssertTrue(ageDiffers)
    }

    // MARK: - Helper Types

    func testEventSubject() {
        let messageSubject: EventSubject<String> = .init()
        messageSubject.send("Hello World")
    }

    func testActionSubject() {
        let didTapButton = ActionSubject()
        didTapButton.send(())
    }

    func testSafeBindingProtocol() {
        struct State: Equatable { var value: String = "" }
        @UIState
        var uiState = State()
        @ValueSubject
        var valueSubject = State()

        func observeState(_ binding: some SafeBinding) {
            binding.justNew()
                .sink { _ in }
                .store(in: &cancellables)
        }

        observeState($uiState)
        // ValueSubject doesn't conform to SafeBinding, so we test it separately
        $valueSubject
            .sink { _ in }
            .store(in: &cancellables)
    }

    // MARK: - MVVM Example

    func testMVVMExample() {
        struct LoginState: BehavioralStateContract {
            var username: String = ""
            var password: String = ""
            var status: String = ""
            @IgnoredState
            var isLoading = false

            mutating func applyRules() {
                if username.isEmpty || password.isEmpty {
                    status = "Please fill all fields"
                } else {
                    status = "Ready to login"
                }
            }

            @SubscriptionBuilder
            static func applyBindingRules(to state: RulesPublisher) -> [AnyCancellable] {
                state.bind(to: \.username) { model in
                    model.status = "Username updated"
                }

                state.bindDiffed(to: \.password) { _, diff in
                    _ = "Password changed from \(diff.old?.count ?? 0) to \(diff.new.count) characters"
                }
            }

            @AnyTokenBuilder<Any>
            static func applyAnyRules(to state: UIBinding<Self>) -> [Any] {
                []
            }
        }

        final class LoginViewModel: ObservableObject {
            @ManagedState
            var state = LoginState()
            private var cancellables = Set<AnyCancellable>()

            init() {
                $state
                    .sink { (diff: DiffedValue<LoginState>) in
                        _ = "State changed from \(diff.old?.status ?? "nil") to \(diff.new.status)"
                    }
                    .store(in: &cancellables)
            }
        }

        let viewModel = LoginViewModel()
        viewModel.state.username = "test"
        viewModel.state.password = "password"

        // ViewController example from documentation
        #if canImport(UIKit)
        final class LoginVC: UIViewController {
            let viewModel = LoginViewModel()
            private var bag = Set<AnyCancellable>()
            var statusLabel: UILabel = .init()
            var usernameField: UITextField = .init()

            override func viewDidLoad() {
                super.viewDidLoad()
                setupBindings()
            }

            private func setupBindings() {
                viewModel.$state
                    .status
                    .sink { [weak self] status in
                        self?.statusLabel.text = status
                    }
                    .store(in: &bag)

                viewModel.$state
                    .bindDiffed(to: \LoginState.username) { [weak self] model, usernameDiff in
                        model.username = usernameDiff.new
                        self?.usernameField.text = usernameDiff.new
                        _ = "Username changed from '\(usernameDiff.old ?? "")' to '\(usernameDiff.new)'"
                    }
                    .store(in: &bag)

                // Safe array access for validation messages
                let validationMessages = ["Username required", "Password too short", "Invalid email"]
                @UIState
                var messages = validationMessages
                let messageBinding = $messages.safe(0, default: "No message")
                messageBinding.wrappedValue = "Ready to validate"
            }

            @objc
            func usernameChanged(_ sender: UITextField) {
                viewModel.state.username = sender.text ?? ""
            }

            @objc
            func passwordChanged(_ sender: UITextField) {
                viewModel.state.password = sender.text ?? ""
            }
        }

        let vc = LoginVC()
        vc.viewDidLoad()
        #endif
    }

    // MARK: - ManagedState Locking

    func testManagedStateLocking() {
        struct MyState: BehavioralStateContract {
            mutating func applyRules() {}
            @SubscriptionBuilder
            static func applyBindingRules(to state: RulesPublisher) -> [AnyCancellable] { [] }
            @AnyTokenBuilder<Any>
            static func applyAnyRules(to state: UIBinding<Self>) -> [Any] { [] }
        }

        @ManagedState
        var state1 = MyState()
        @ManagedState(lock: .absent)
        var state2 = MyState()
        @ManagedState(lock: .custom(NSRecursiveLock()))
        var state3 = MyState()

        $state1.withLock { value in
            _ = value
        }

        $state2.withLock { value in
            _ = value
        }

        $state3.withLock { value in
            _ = value
        }
    }
}

// MARK: - Custom Extensions for Documentation Examples

/// Custom extension example from documentation for ExpressibleByNilLiteral support
public extension UIBinding where Value: ExpressibleByNilLiteral {
    init(nilLiteral: ()) {
        self = .constant(nil)
    }
}
