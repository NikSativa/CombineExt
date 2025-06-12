# CombineExt

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FNikSativa%2FCombineExt%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/NikSativa/CombineExt)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FNikSativa%2FCombineExt%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/NikSativa/CombineExt)
[![NikSativa CI](https://github.com/NikSativa/CombineExt/actions/workflows/swift_macos.yml/badge.svg)](https://github.com/NikSativa/CombineExt/actions/workflows/swift_macos.yml)
[![License](https://img.shields.io/github/license/Iterable/swift-sdk)](https://opensource.org/licenses/MIT)

**CombineExt** is a lightweight and extensible toolkit for building reactive applications using Combine in Swift. Designed with UIKit developers in mind, CombineExt enables declarative state management and binding similar to SwiftUI—while preserving the flexibility and familiarity of UIKit. It supports clean architectural patterns such as MVVM and MVI, reducing boilerplate and improving maintainability.

---

## ✨ Getting Started

### 📦 Installation

You can install CombineExt using [Swift Package Manager](https://swift.org/package-manager/):

1. In Xcode, open your project settings.
2. Go to **Package Dependencies**.
3. Tap the **+** button and search:
```
https://github.com/NikSativa/CombineExt.git
```
or add the collection that includes all related frameworks:
```
https://swiftpackageindex.com/NikSativa/collection.json
``` 
---

## ❓ When to Use CombineExt

CombineExt is ideal for:

- UIKit projects where you want SwiftUI-style reactivity without migrating your UI framework.
- Structuring model logic using the MVVM or MVI architecture patterns.
- Avoiding boilerplate code for managing state, actions, and notifications.
- Safely observing and binding deeply nested model or UI properties, including collections.
- Building scalable, testable reactive state containers that integrate smoothly with Combine.

If your project involves complex state management, reactive UI updates, or you want to unify your approach to state and action handling, CombineExt provides a clean, extensible foundation.

---

## 🚀 Features at a Glance

- **ManagedState**: A property wrapper that helps manage your model's state and actions with a reactive, testable API.
- **UIState / UIBinding**: Property wrappers for observing and binding value types in a reactive way.
- **Safe bindings** to nested or out-of-bounds array elements using `safe`.
- **ValueSubject**: A `@Published`-like wrapper for reference semantics, ideal for UIKit workflows.

---

## 🧠 ManagedState

Use `ManagedState` to manage a model conforming to `BehavioralStateContract`. It encapsulates action handling, binding setup, and notification handling, allowing you to keep your model logic clean and reactive.

### Example

```swift
struct CounterModel: BehavioralStateContract {
    enum Action {
        case increment
    }

    var count: Int = 0
    private(set) var isOdd: Bool = false

    // Handle incoming actions to update the model state
    mutating func receive(_ action: Action) {
        switch action {
        case .increment: 
            count += 1
        }
    }

    // Optional hook called after actions have been processed
    mutating func postActionsProcessing() {
        // Finalize state after action is handled (optional)
        isOdd = (count % 2) == 1
    }
    
    @SubscriptionBuilder
    static func applyBindingRules(for state: UIBinding<Self>, to receiver: EventSubject<Self.Action>) -> [AnyCancellable] {
        // nothing to do in that example
    }
    
    @NotificationBuilder
    static func applyNotificationRules(to state: ManagedState<Self>) -> [NotificationToken] {
        // nothing to do in that example
    }
}
```

### Usage

```swift
@ManagedState 
var model: CounterModel = .init()
var cancellables: Set<AnyCancellable> = []

$model.sink { new in 
    print(new.count, new.isOdd)
}.store(in: cancellables)

model.send(.increment)
// Output: 1 true

model.send(.increment)
// Output: 2 false

model.send(.increment)
// Output: 3 true

model.count = 10
// Output: 10 false
// direct mutation trigger `postActionsProcessing()` 

model.count = 1
// Output: 1 true

model.count += 9
// Output: 10 false
```

### Features

- Automatically integrates binding and notification rules.
- Bind to nested properties with `.state(\.property)` and `.coordinator(\.nestedModel)`.
- Use `$model.keyPath` or `.observe(\.keyPath)` for Combine bindings.
- Supports clean separation of actions and state updates for better testability.
- `postActionsProcessing()` is automatically called after any mutation of the model, whether the change comes from an action (`send`) or direct property mutation. This ensures derived state (like computed flags) stays consistent without requiring manual updates.
- `applyBindingRules(for:to:)` is to declaratively define how your model binds to UI interactions using Combine. This uses a custom result builder (`@SubscriptionBuilder`) to cleanly return a list of `AnyCancellable` subscriptions.
- `applyNotificationRules(to:)` is to declare how your model responds to external events such as system notifications. This leverages a custom result builder (`@NotificationBuilder`) to produce a list of active `NotificationToken` objects.

---

## 🪄 UIState & UIBinding

Use `@UIState` to track changes in value types reactively. It supports fine-grained reactivity, nested state observation, and safe access to collections.

### Basic Usage

```swift
struct ViewState: Equatable {
    var counter: Int
    var toggle: Bool
}

@UIState var state = ViewState(counter: 0, toggle: false)

// Observe changes to the counter property reactively
$state.counter
    .sink { print("Counter:", $0) }
    .store(in: &observers)

state.counter += 1
```

### Observe Nested Properties

You can observe deeply nested properties without boilerplate:

```swift
struct Profile {
    var name: String
    var details: Details
}

struct Details {
    var age: Int
}

@UIState var profile = Profile(name: "Alice", details: .init(age: 30))

let ageBinding = $profile.details.age
ageBinding.wrappedValue = 31
```

### Safe Access in Collections

Safely access array elements by avoiding crashes on out-of-bounds or nil entries:

```swift
@UIState var items: [String?] = ["A", "B"]

let item = $items.safe(0)
print(item.wrappedValue ?? "nil") // "A"

let fallback = $items.safe(10, default: "Default")
print(fallback.wrappedValue) // "Default"

let optionalItem = $items.safe(2)
print(optionalItem.wrappedValue ?? "nil") // "nil"
```

This ensures your UI remains stable and reactive even with dynamic collections.

---

## 📬 ValueSubject

A reference-based reactive value holder that mimics `@Published` but allows shared ownership and mutation, making it well-suited for UIKit views and other reference-type state.

Unlike `@Published`, `ValueSubject` allows explicit mutation of shared state across multiple owners without relying on value-type semantics. This makes it ideal for bridging shared mutable state in view controllers or service layers.

### Example

```swift
struct FormState: Equatable {
    var name: String
    var email: String
}

@ValueSubject var form = FormState(name: "", email: "")

// Observe changes to the name property
$form.name
    .sink { print("Name changed:", $0) }
    .store(in: &observers)

form.name = "Nik"
```

`ValueSubject` helps when you want to share mutable state across multiple owners while still benefiting from Combine’s reactive streams.

---

## ✅ Summary

**CombineExt** provides UIKit developers with a structured, SwiftUI-like approach to building reactive applications. It simplifies state and action handling, reduces boilerplate, and facilitates implementation of MVVM or MVI patterns. Whether managing simple counters or complex nested models, CombineExt offers powerful abstractions that streamline development and testing.

---

## 💬 Contributing

Contributions, feedback, and pull requests are welcome. Please open an issue or submit a pull request if you would like to help improve the library.

---

## 📄 License

CombineExt is available under the MIT license. See the [LICENSE](LICENSE) file for more information.
