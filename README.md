[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FNikSativa%2FCombineExt%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/NikSativa/CombineExt)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FNikSativa%2FCombineExt%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/NikSativa/CombineExt)
[![NikSativa CI](https://github.com/NikSativa/CombineExt/actions/workflows/swift_macos.yml/badge.svg)](https://github.com/NikSativa/CombineExt/actions/workflows/swift_macos.yml)
[![License](https://img.shields.io/github/license/Iterable/swift-sdk)](https://opensource.org/licenses/MIT)

# CombineExt

**CombineExt** is a lightweight, extensible Combine utility library designed for UIKit developers. It brings a SwiftUI-style reactive approach to state and action management, while keeping UIKit's flexibility. Ideal for MVVM or MVI architecture, it simplifies your reactive stack and reduces boilerplate.

## 📦 Installation

Add via Swift Package Manager:

```
https://github.com/NikSativa/CombineExt.git
```

Or add the collection of related packages:

```
https://swiftpackageindex.com/NikSativa/collection.json
```

## 🚀 Features

- `@ManagedState`: Reactive model wrapper with built-in action and side-effect support.
- `@UIState` and `@UIBinding`: Two-way reactive value wrappers for UI and data state.
- Safe array access via `.safe(index)` to avoid out-of-bounds crashes.
- `@ValueSubject`: Reference-based observable state, similar to `@Published` but with shared ownership.
- Declarative binding/notification DSL with `SubscriptionBuilder` and `NotificationBuilder`.

## 🧠 `ManagedState` for Reactive Models

Encapsulate a stateful model and its logic reactively:

```swift
struct CounterModel: BehavioralStateContract {
    var displayText: String = "0"
    var count: Int = 0
    var isOdd: Bool = false
    
    /// Applies internal consistency rules to the model.
    ///
    /// This method is invoked automatically after state mutations to derive
    /// secondary values based on core model properties.
    ///
    /// For example, `isOdd` is updated to reflect whether the `count` value is odd.
    mutating func applyRules() {
        isOdd = count % 2 != 0 // variant 1
    }

    /// Defines reactive state bindings using Combine pipelines.
    ///
    /// This method binds specific value changes from the model to logic that updates
    /// other parts of the model. It enables automatic propagation of computed state
    /// whenever source properties change.
    ///
    /// - Parameter state: A publisher emitting diffs of model state.
    ///
    /// ### Example
    /// Use `bindDiffed(to:)` to react to value changes using both the old and new state.
    @SubscriptionBuilder
    static func applyBindingRules(to state: RulesPublisher) -> [AnyCancellable] {
        // variant 2: `pair` contains `old` & `new` states, so easily to handle changes
        state.bindDiffed(to: \.count) { pair in
            pair.new.displayText = "was: \(pair.old.count) - now: \(pair.new.count)"
        }
    }

    /// Registers external notification rules that affect the model.
    ///
    /// Use this to listen to app-wide notifications (e.g., `NotificationCenter`) and apply side effects to the model state.
    ///
    /// - Parameter state: A reference to the managed state.
    /// - Returns: An array of tokens keeping observers alive.
    @NotificationBuilder
    static func applyAnyRules(to state: ManagedState<Self>) -> [NotificationToken] {
        // External observers (e.g., NotificationCenter)
    }
}
```

### Usage

```swift
@ManagedState var model = CounterModel()
$model.sink { print("Count:", $0.count) }.store(in: &cancellables)
model.send(.increment)
```

## 🪄 `@UIState` & `@UIBinding`

Bind and observe nested values with minimal boilerplate:

```swift
struct ViewState { var isOn: Bool }
@UIState var state = ViewState(isOn: false)

$state.isOn
    .sink { print("Toggle is now:", $0) }
    .store(in: &cancellables)

state.isOn = true
```

### Safe Collection Access

```swift
@UIState var names: [String?] = ["A", "B"]

let name = $names.safe(10, default: "Fallback")
print(name.wrappedValue) // "Fallback"
```

## 🔁 `@ValueSubject`

A mutable, shared, observable value reference:

```swift
struct Form { var name: String }
@ValueSubject var form = Form(name: "")

$form.name
    .sink { print("Name changed to:", $0) }
    .store(in: &cancellables)

form.name = "Nik"
```

## 🧱 MVVM Example

### ViewModel

```swift
struct LoginState: BehavioralStateContract {
    enum Action { case loginTapped }
    var username: String = ""
    var status: String = ""

    mutating func receive(_ action: Action) {
        if case .loginTapped = action {
            status = username.isEmpty ? "Missing input" : "Logging in..."
        }
    }
}

final class LoginViewModel: ObservableObject {
    @ManagedState var state = LoginState()
}
```

### ViewController

```swift
final class LoginVC: UIViewController {
    let viewModel = LoginViewModel()
    var bag = Set<AnyCancellable>()

    override func viewDidLoad() {
        super.viewDidLoad()
        viewModel.$state.status
            .sink { print("Status:", $0) }
            .store(in: &bag)

        viewModel.state.username = "user"
        viewModel.state.send(.loginTapped)
    }
}
```

## ✅ Summary

CombineExt simplifies building reactive UIKit applications:

- Declarative, composable state management.
- SwiftUI-style bindings with no migration.
- Clean architecture support (MVVM/MVI).
- Type-safe, testable, Combine-friendly code.

## 💬 Contributing

Issues, suggestions, and pull requests are welcome!

## 📄 License

MIT. See the [LICENSE](LICENSE) file for details.
