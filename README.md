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

- **Reactive State Management**: `@ManagedState`, `@UIState`, `@UIBinding`, `@ValueSubject` for different reactive patterns
- **Smart Property Wrappers**: `@IgnoredState` for transient data that doesn't affect equality/hashing
- **Thread Safety**: `withLock` for atomic operations, preventing race conditions in concurrent code
- **Safe Operations**: Safe collection access, nil filtering, and crash prevention
- **Advanced Binding**: Rich binding DSL with both `WritableKeyPath` and `KeyPath` support
- **Extended Publishers**: `CombineLatest5/6`, `Zip5/6` for complex data flows
- **State Tracking**: `DiffedValue` for state transitions with old and new values
- **Publisher Extensions**: `filterNils()`, `mapVoid()`, and advanced binding methods
- **Declarative DSL**: `SubscriptionBuilder` and `AnyTokenBuilder` for clean reactive code
- **Dynamic Callable**: Property wrapper syntax for intuitive API usage
- **Utility Functions**: `differs()` for efficient value comparison with key paths
- **Comprehensive Testing**: 216+ tests ensuring reliability and stability

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
    @AnyTokenBuilder<Any>
    static func applyAnyRules(to state: UIBinding<Self>) -> [Any] {
        // External observers (e.g., NotificationCenter)
        []
    }
}
```

### Usage

```swift
@ManagedState var model = CounterModel()
$model.sink { print("Count:", $0.count) }.store(in: &cancellables)
model.count += 1
```

### Dynamic Callable Support

`@ManagedState` supports dynamic callable syntax via projected value:

```swift
@ManagedState var model = CounterModel()

// Access entire value (using $ projected value)
let binding = $model() // Returns binding to entire CounterModel

// Access specific properties (using $ projected value)
let countBinding = $model(\.count) // Returns binding to count property
let displayBinding = $model(\.displayText) // Returns binding to displayText property

// Update through bindings (automatically applies rules)
countBinding.wrappedValue = 10
displayBinding.wrappedValue = "Updated"
```

`$model.ui` returns the same binding as `$model()`. A dynamic member of it returns a binding to a property: `$model.ui.count` is a `UIBinding<Int>`.

## 🪄 `@UIState` & `@UIBinding`

Bind and observe nested values with minimal boilerplate:

```swift
struct ViewState: Equatable { var isOn: Bool }
@UIState var state = ViewState(isOn: false)

$state.ui.isOn
    .sink { print("Toggle is now:", $0.new) }
    .store(in: &cancellables)

state.isOn = true
```

`@UIState` gives access to a property as `@ManagedState` does:

| Form | Result |
|---|---|
| `state.isOn` | the value |
| `$state[\.isOn]` | the value |
| `$state.isOn` | SwiftUI `Binding<Bool>` |
| `$state.ui.isOn` | `UIBinding<Bool>` |

`$state.ui` returns the same binding as `$state()`.

`@UIState` has a lock and supports the Observation framework, as `@ManagedState` does. A single read or a single write is thread-safe. Use `$state.withLock { value in ... }` for a read-modify-write operation. See [Locking](#locking) and [SwiftUI Integration with Observation](#-swiftui-integration-with-observation).

`UIBinding` is the UIKit analog of the SwiftUI `Binding`. A dynamic member of a `UIBinding` returns a `UIBinding` to the property, as a dynamic member of a `Binding` returns a `Binding`.

### Dynamic Callable Support

`@UIState` and `@UIBinding` support dynamic callable syntax via projected value:

```swift
struct ViewState: Equatable { var isOn: Bool }
@UIState var state = ViewState(isOn: false)

// Access entire value (using $ projected value)
let binding = $state() // Returns binding to entire ViewState

// Access specific properties (using $ projected value)
let isOnBinding = $state(\.isOn) // Returns binding to isOn property

// Update through bindings
isOnBinding.wrappedValue = true
```

**Note:** The examples above show `@UIState` as a property wrapper. Always use `@UIState` syntax, not `UIState(...)` initialization.

### Safe Collection Access

```swift
@UIState var names: [String?] = ["A", "B"]

let name = $names.safe(10, default: "Fallback")
print(name.wrappedValue) // "Fallback"

let safeItem = $names.safe(1)
print(safeItem.wrappedValue ?? "nil") // "B"
```

### UIBinding as Property Wrapper

`UIBinding` can be used as a property wrapper. You typically initialize it by assigning a binding from `@UIState` or `@ManagedState`:

**Example:**

```swift
struct State: Equatable { var name: String }
@UIState var state = State(name: "name")

final class MyView: UIView {
    @UIBinding(.placeholder) private var name: String
    private var cancellables: Set<AnyCancellable> = []

    func configure(withName binding: UIBinding<String>) {
        _name = binding
        
        // Subscribe to changes (receives DiffedValue)
        $name
            .sink { diff in
                print("Name changed to: \(diff.new)")
            }
            .store(in: &cancellables)
        
        // Or subscribe to just new values
        $name.publisher
            .sink { newName in
                print("Name changed to: \(newName)")
            }
            .store(in: &cancellables)
    }

    func buttonTapped() {
        name = "new name" // Direct access to wrapped value
    }
}

let view = MyView(frame: .zero)
view.configure(withName: $state.ui.name)
view.buttonTapped()
```

**Using with uninitialized binding:**

```swift
final class MyView: UIView {
    @UIBinding(.placeholder) private var name: String
    private var cancellables: Set<AnyCancellable> = []
    
    func configure(withName binding: UIBinding<String>) {
        _name = binding
    }
}

let view = MyView(frame: .zero)
struct State: Equatable { var name: String }
@UIState var state = State(name: "test")
view.configure(withName: $state.ui.name)
```

**Using with constant binding:**

You can assign a constant binding to a property wrapper using `_binding = .constant(...)`:

```swift
final class MyView: UIView {
    @UIBinding(.placeholder) private var name: String
    private var cancellables: Set<AnyCancellable> = []
    
    func configure(withName binding: UIBinding<String>) {
        _name = binding
    }
}

let view = MyView(frame: .zero)
view.configure(withName: .constant("test"))
```

**Direct usage (not as property wrapper):**

For read-only bindings that never emit changes, use the static `constant(_:)` method:

```swift
// Create a constant binding for a fixed title
let titleBinding = UIBinding<String>.constant("Fixed Title")

// Reading works
print(titleBinding.wrappedValue) // Prints: "Fixed Title"

// Setting is ignored
titleBinding.wrappedValue = "New Title"
print(titleBinding.wrappedValue) // Still prints: "Fixed Title"

// Subscribe to changes (receives DiffedValue)
titleBinding
    .sink { diff in
        print("Changed from \(diff.old ?? "nil") to \(diff.new)")
    }
    .store(in: &cancellables)

// Or subscribe to just new values
titleBinding.publisher
    .sink { newTitle in
        print("New title: \(newTitle)")
    }
    .store(in: &cancellables)

// Useful for preview or placeholder data
struct ContentView: View {
    var binding: UIBinding<String>

    static var previews: some View {
        ContentView(binding: .constant("Preview Data"))
    }
}
```

**Implementation:**

```swift
/// Creates a constant binding that cannot be modified.
///
/// Use this method to create a read-only binding that always returns the same value.
/// Any attempts to set a new value will be ignored.
static func constant(_ value: Value) -> Self {
    return .init(get: { value },
                 set: { new in Swift.print("Attempted to set on constant binding \(new)") })
}
```

### Custom Extensions

You can extend `UIBinding` with additional functionality as needed for your project. The library provides the core functionality, but you're free to add convenience extensions that fit your specific use cases.

**Example: ExpressibleByNilLiteral Support**

If you need to initialize `UIBinding` with `nil` for optional types, you can add this extension:

```swift
extension UIBinding where Value: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) {
        self = .constant(nil)
    }
}

// Usage:
final class MyView: UIView {
    @UIBinding(.placeholder) private var optionalName: String?
}
```

**Note:** This extension is not included in the library by default, as it may not be needed for all projects. Add it only if it fits your use case.

## 🔁 `@ValueSubject`

A mutable, shared, observable value reference:

```swift
struct Form: Equatable { var name: String }
@ValueSubject var form = Form(name: "")

$form
    .map(\.name)
    .sink { print("Name changed to:", $0) }
    .store(in: &cancellables)

form.name = "Nik"
```

### Dynamic Callable Support

`@ValueSubject` supports dynamic callable syntax via projected value:

```swift
struct User: Equatable {
    var name: String = "John"
    var age: Int = 25
}

@ValueSubject var user = User()
let binding = $user

// Subscribe to changes
$user
    .sink { _ in }
    .store(in: &cancellables)

// Update values directly
user.name = "Jane"
user.age = 30
```

## 🎯 `@IgnoredState` for Transient Data

Use `@IgnoredState` to wrap values that should not affect equality or hashing:

```swift
struct DataCache: Equatable {
    static func == (lhs: DataCache, rhs: DataCache) -> Bool { true }
}

struct ViewModel: Equatable {
    var title: String = "Hello"
    @IgnoredState var cache = DataCache()
    @IgnoredState var timer: Timer?
    
    // Only `title` affects equality, `cache` and `timer` are ignored
}

let vm1 = ViewModel()
var vm2 = ViewModel()
vm2.cache = DataCache() // Different cache
print(vm1 == vm2) // true - cache is ignored
```

### Dynamic Callable Support

`@IgnoredState` supports dynamic callable syntax for closures:

```swift
// Wrapping closures - enables direct call syntax
@IgnoredState var formatter: (Double) -> String = { value in
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
}

// Call the wrapped closure directly
let price = formatter(99.99) // "$99.99"

// Counter example
@IgnoredState var counter: () -> Int = {
    var count = 0
    count += 1
    return count
}

print(counter()) // 1
print(counter()) // 2
```

### With Custom IDs

```swift
struct Model: Hashable {
    @IgnoredState(id: 1) var cache1 = Data()
    @IgnoredState(id: 2) var cache2 = Data()
    // Different IDs make them distinct for hashing
}
```

## 📊 `DiffedValue` for State Transitions

Track both old and new values during state changes:

```swift
@UIState var counter = 0

$counter.publisher
    .sink { diff in
        print("Changed from \(diff.old ?? 0) to \(diff.new)")
        // diff.old is nil on first emission
    }
    .store(in: &cancellables)

counter = 5 // Prints: "Changed from 0 to 5"
```

### Dynamic Member Access

```swift
struct User: Equatable { var name: String; var age: Int }
@UIState var user = User(name: "Alice", age: 30)

$user.publisher
    .sink { diff in
        let _ = diff.name // Direct property access
        let _ = diff.age
    }
    .store(in: &cancellables)
```

## 🔧 Publisher Extensions

### Filtering and Mapping

```swift
// Filter out nil values
Just<String?>(nil)
    .filterNils()
    .sink { print($0) } // Won't be called

Just("Hello")
    .filterNils()
    .sink { print($0) } // Prints "Hello"

// Map to Void for side effects
button.tapPublisher
    .mapVoid()
    .sink { print("Button tapped") }
    .store(in: &cancellables)
```

### Advanced Binding Methods

```swift
struct Profile: Equatable {
    var name: String = ""
}

struct Model: BehavioralStateContract {
    var username: String = ""
    var count: Int = 0
    var profile: Profile = Profile()
    var readOnlyProperty: String = ""
    var computedProperty: String = ""
    
    mutating func applyRules() {}
    @SubscriptionBuilder
    static func applyBindingRules(to state: RulesPublisher) -> [AnyCancellable] { [] }
    @AnyTokenBuilder<Any>
    static func applyAnyRules(to state: UIBinding<Self>) -> [Any] { [] }
}

@UIState var state = Model()

// Bind to specific property changes (WritableKeyPath)
$state.publisher
    .bind(to: \Model.username) { model in
        model.username = "updated"
    }
    .store(in: &cancellables)

// Bind with both old and new values (WritableKeyPath)
$state.publisher
    .bindDiffed(to: \Model.count) { model, diff in
        print("Count changed from \(diff.old ?? 0) to \(diff.new)")
    }
    .store(in: &cancellables)

// Bind to nested properties (WritableKeyPath)
$state.publisher
    .bind(to: \Model.profile.name) { name in
        name = name.uppercased()
    }
    .store(in: &cancellables)

// Read-only bindings (KeyPath) - for observing without modification
$state.publisher
    .bind(to: \Model.readOnlyProperty) { value in
        print("Read-only property changed to: \(value)")
    }
    .store(in: &cancellables)

// Read-only diffed bindings (KeyPath)
$state.publisher
    .bindDiffed(to: \Model.computedProperty) { model, diff in
        print("Computed property changed from \(diff.old ?? "nil") to \(diff.new)")
    }
    .store(in: &cancellables)
```

## 🔗 Extended Combine Publishers

### CombineLatest5 and CombineLatest6

```swift
let name = PassthroughSubject<String, Never>()
let age = PassthroughSubject<Int, Never>()
let email = PassthroughSubject<String, Never>()
let isActive = PassthroughSubject<Bool, Never>()
let lastLogin = PassthroughSubject<Date, Never>()

Publishers.CombineLatest5(name, age, email, isActive, lastLogin)
    .sink { name, age, email, isActive, lastLogin in
        print("User: \(name), \(age), \(email), active: \(isActive)")
    }
    .store(in: &cancellables)
```

### Zip5 and Zip6

```swift
let step1 = PassthroughSubject<String, Never>()
let step2 = PassthroughSubject<String, Never>()
let step3 = PassthroughSubject<String, Never>()
let step4 = PassthroughSubject<String, Never>()
let step5 = PassthroughSubject<String, Never>()

Publishers.Zip5(step1, step2, step3, step4, step5)
    .sink { step1, step2, step3, step4, step5 in
        print("All steps completed: \([step1, step2, step3, step4, step5])")
    }
    .store(in: &cancellables)
```

## 🛡️ Safe Collection Access

Access array elements safely without crashes:

```swift
@UIState var items = ["A", "B", "C"]

// Safe access with default value
let item = $items.safe(10, default: "Not Found")
print(item.wrappedValue) // "Not Found"

// Safe access using current value as default
let safeItem = $items.safe(1)
print(safeItem.wrappedValue) // "B"

// Unsafe access (will crash if out of bounds)
let unsafeItem = $items.unsafe(1)
print(unsafeItem.wrappedValue) // "B"

// Create bindings for all array elements
let bindings = $items.bindingArray()
bindings[0].wrappedValue = "Updated"
```

## 🛠️ Utility Functions

### `differs()` for Efficient Value Comparison

Compare values at specific key paths efficiently with inlined performance:

```swift
struct Person {
    let name: String
    let age: Int
}

let person1 = Person(name: "Alice", age: 30)
let person2 = Person(name: "Bob", age: 25)

// Check if specific properties differ
let nameDiffers = differs(lhs: person1, rhs: person2, keyPath: \.name)  // true
let ageDiffers = differs(lhs: person1, rhs: person2, keyPath: \.age)    // true
```

**Performance Note**: This function is marked with `@inline(__always)` for optimal performance in reactive scenarios where it's called frequently.

## 🏗️ Helper Types

### EventSubject and ActionSubject

```swift
// For general events
let messageSubject: EventSubject<String> = .init()
messageSubject.send("Hello World")

// For simple actions (Void events)
let didTapButton = ActionSubject()
didTapButton.send(()) // Trigger action
```

### SafeBinding Protocol

All reactive wrappers conform to `SafeBinding` for consistent API:

```swift
struct State: Equatable { var value: String = "" }
@UIState var uiState = State()
@ValueSubject var valueSubject = State()

func observeState(_ binding: some SafeBinding) {
    binding.justNew()
        .sink { newValue in
            print("New value: \(newValue)")
        }
        .store(in: &cancellables)
}

// Works with UIState (conforms to SafeBinding)
observeState($uiState)

// ValueSubject doesn't conform to SafeBinding, so we test it separately
$valueSubject
    .sink { _ in }
    .store(in: &cancellables)
```

## 🧱 MVVM Example

### ViewModel

```swift
struct LoginState: BehavioralStateContract {
    var username: String = ""
    var password: String = ""
    var status: String = ""
    @IgnoredState var isLoading = false

    mutating func applyRules() {
        // Auto-validate on changes
        if username.isEmpty || password.isEmpty {
            status = "Please fill all fields"
        } else {
            status = "Ready to login"
        }
    }

    @SubscriptionBuilder
    static func applyBindingRules(to state: RulesPublisher) -> [AnyCancellable] {
        // React to username changes
        state.bind(to: \.username) { model in
            model.status = "Username updated"
        }
        
        // React to password changes with diff
        state.bindDiffed(to: \.password) { model, diff in
            print("Password changed from \(diff.old?.count ?? 0) to \(diff.new.count) characters")
        }
    }
}

final class LoginViewModel: ObservableObject {
    @ManagedState var state = LoginState()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Observe state changes
        $state
            .sink { (diff: DiffedValue<LoginState>) in
                print("State changed from \(diff.old?.status ?? "nil") to \(diff.new.status)")
            }
            .store(in: &cancellables)
    }
}
```

### ViewController

```swift
final class LoginVC: UIViewController {
    let viewModel = LoginViewModel()
    private var bag = Set<AnyCancellable>()
    var statusLabel: UILabel = UILabel()
    var usernameField: UITextField = UITextField()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupBindings()
    }
    
    private func setupBindings() {
        // Observe status changes
        viewModel.$state.ui.status
            .sink { [weak self] status in
                self?.statusLabel.text = status
            }
            .store(in: &bag)
            
        // Observe username changes with diff
        viewModel.$state
            .bindDiffed(to: \LoginState.username) { [weak self] model, usernameDiff in
                model.username = usernameDiff.new
                self?.usernameField.text = usernameDiff.new
                print("Username changed from '\(usernameDiff.old ?? "")' to '\(usernameDiff.new)'")
            }
            .store(in: &bag)
            
        // Safe array access for validation messages
        let validationMessages = ["Username required", "Password too short", "Invalid email"]
        @UIState var messages = validationMessages
        let messageBinding = $messages.safe(0, default: "No message")
        messageBinding.wrappedValue = "Ready to validate"
    }
    
    @objc func usernameChanged(_ sender: UITextField) {
        viewModel.state.username = sender.text ?? ""
    }
    
    @objc func passwordChanged(_ sender: UITextField) {
        viewModel.state.password = sender.text ?? ""
    }
}
```

## 🔬 SwiftUI Integration with `ObservableObject`

Use `@ManagedState` inside an `ObservableObject` ViewModel. Bridge `objectWillChange` so SwiftUI re-renders on state changes:

```swift
struct AppState: BehavioralStateContract {
    var title: String = "Initial"

    mutating func applyRules() {}

    @SubscriptionBuilder
    static func applyBindingRules(to state: RulesPublisher) -> [AnyCancellable] {
        []
    }

    @AnyTokenBuilder<Any>
    static func applyAnyRules(to state: UIBinding<AppState>) -> [Any] {
        []
    }
}

final class ViewModel: ObservableObject {
    @ManagedState
    var state: AppState = .init()

    private var cancellable: AnyCancellable?

    init() {
        cancellable = $state.publisher
            .dropFirst()
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
    }
}
```

### Usage in SwiftUI

```swift
struct ContentView: View {
    @ObservedObject var viewModel = ViewModel()

    var body: some View {
        Text(viewModel.state.title)
        Button("Update") {
            viewModel.state.title = "Updated"
        }
    }
}
```

### Observe changes via Combine

```swift
let viewModel = ViewModel()

viewModel.$state.publisher
    .sink { state in
        print("Title: \(state.title)")
    }
    .store(in: &cancellables)

viewModel.state.title = "Updated" // triggers sink + objectWillChange
```

## 🔭 SwiftUI Integration with Observation

`ManagedState` and `UIState` conform to `Observable` from the Observation framework. This support needs iOS 17, macOS 14, tvOS 17, watchOS 10, or visionOS 1. The examples below use `@ManagedState`. `@UIState` tracks reads and notifies observers by the same rules.

An `@Observable` ViewModel can keep its state in `@ManagedState`. The `@Observable` macro cannot track a property that has a property wrapper, so mark the property with `@ObservationIgnored`. SwiftUI still tracks the state, because each read of `wrappedValue` registers an Observation access.

```swift
@Observable
final class ViewModel {
    @ObservationIgnored
    @ManagedState
    private var viewState = AppState()

    var state: AppState {
        return viewState
    }

    func rename(to title: String) {
        viewState.title = title
    }
}

struct ContentView: View {
    @State private var viewModel = ViewModel()

    var body: some View {
        Text(viewModel.state.title)
        Button("Update") {
            viewModel.rename(to: "Updated")
        }
    }
}
```

A ViewModel can also conform to `Observable` without the macro. Then `@ManagedState` needs no `@ObservationIgnored`.

```swift
final class ViewModel: Observable {
    @ManagedState
    private(set) var viewState = AppState()

    func rename(to title: String) {
        viewState.title = title
    }
}
```

`viewModel.viewState.title` tracks the whole value. `viewModel.$viewState[\.title]` tracks only `title`. Without the macro, Observation does not track other stored properties of the ViewModel.

### Access to a field

The access works as with a SwiftUI `@State` property. Each form has one result type:

| Form | Result | Observation tracks |
|---|---|---|
| `state.title` | the value | the whole value |
| `$state[\.title]` | the value | only `title` |
| `$state.title` | SwiftUI `Binding<String>` | only `title` |
| `$state.ui.title` | `UIBinding<String>` | the whole value |

- `$state[\.trip.title]` tracks the full key path as one field.
- `$state.trip.title` is a binding to `trip.title`. A read through it tracks the field `trip`.
- If the type of the field is not `Equatable`, the read tracks the whole value.

### Track one field

A read of `wrappedValue` tracks the whole value. In the example above, `viewModel.state.title` reads `wrappedValue`, so the view gets a notification for a change of any field. To track one field, read it with `$state[\.title]`.

```swift
@Observable
final class TripViewModel {
    @ObservationIgnored
    @ManagedState
    private(set) var state = TripState()

    func rename(to title: String) {
        state.title = title
    }
}

struct TripView: View {
    let viewModel: TripViewModel

    var body: some View {
        VStack {
            Text(viewModel.$state[\.title])
            Text(viewModel.$state[\.trip.title])
            TextField("Title", text: viewModel.$state.title)
        }
    }
}
```

`TripView` reads only `title` and `trip.title`. SwiftUI runs its `body` again only when one of these fields gets a different value. A change of `trip.seats` does not notify it.

UIKit code can use the same reads in `withObservationTracking(_:onChange:)`:

```swift
withObservationTracking {
    titleLabel.text = viewModel.$state[\.title]
} onChange: {
    print("The title changes")
}
```

### Notification rules

- One change sends one notification for the whole value and one notification for each tracked field that gets a different value.
- `withObservationTracking(_:onChange:)` calls `onChange` only for the first notification. A `withLock(_:)` call that changes several fields calls `onChange` of an observer one time.
- An observer that reads `wrappedValue` gets a notification for each change. An observer that reads only fields gets a notification only when one of these fields changes.
- The rules run before the notification. The observers get only the final value, not the intermediate values of the rules. A field that the rules change also notifies its observers.
- A change to an equal value does not notify the observers.
- The observers receive the notification before the stored value changes, as with the `@Observable` macro. A read in `onChange` returns the old value.
- `ManagedState` notifies the observers while it holds its lock. If an observer reads the value in `onChange`, use `.synced`, `.absent`, or a recursive `.custom` lock.
- Change a value that a view reads on the main actor, as with any `@Observable` type.

## 📱 Platform Support

CombineExt supports all major Apple platforms:

- **iOS 16+** - Full support for UIKit reactive patterns
- **macOS 14+** - AppKit and SwiftUI compatibility
- **tvOS 16+** - tvOS interface development
- **watchOS 9+** - Watch app state management
- **visionOS 1+** - Vision Pro app development
- **macCatalyst 16+** - iPad apps on Mac

## 🔧 Advanced Configuration

### Locking

`@UIState` and `@ManagedState` use the same lock type, `StateLock`:

```swift
// Thread-safe (default)
@ManagedState var state = MyState()
@UIState var counter = 0

// No locking for single-threaded contexts
@ManagedState(lock: .absent) var state = MyState()
@UIState(lock: .absent) var counter = 0

// Custom lock
@ManagedState(lock: .custom(NSRecursiveLock())) var state = MyState()
@UIState(lock: .custom(NSRecursiveLock())) var counter = 0
```

If the initializer gets no lock, the state uses `StateDefaultLock`. The default value is `.synced`. `ManagedStateLock` and `ManagedStateDefaultLock` are the deprecated names of `StateLock` and `StateDefaultLock`.

### Thread Safety and Race Conditions

⚠️ **Important**: While individual property access is thread-safe, compound operations like `state.count += 1` are NOT atomic and may cause race conditions in concurrent code.

```swift
// ❌ NOT thread-safe in concurrent code:
state.count += 1

// ✅ Thread-safe alternatives:
state.count = state.count + 1  // Direct assignment
state.withLock { value in      // Atomic operation
    value.count += 1
}
```

### Atomic Operations with `withLock`

Use `withLock` for atomic read-modify-write operations:

```swift
struct MyState: BehavioralStateContract {
    mutating func applyRules() {}
    @SubscriptionBuilder
    static func applyBindingRules(to state: RulesPublisher) -> [AnyCancellable] { [] }
    @AnyTokenBuilder<Any>
    static func applyAnyRules(to state: UIBinding<Self>) -> [Any] { [] }
}

@ManagedState var state1 = MyState()
@ManagedState(lock: .absent) var state2 = MyState()
@ManagedState(lock: .custom(NSRecursiveLock())) var state3 = MyState()

// Atomic operations with lock
$state1.withLock { value in
    let _ = value
}

// No locking for single-threaded contexts
$state2.withLock { value in
    let _ = value
}

// Custom lock
$state3.withLock { value in
    let _ = value
}
```

### Cyclic Dependency Detection

```swift
// Disable warnings in tests
ManagedStateCyclicDependencyWarning = false
ManagedStateCyclicDependencyMaxDepth = 50
```

## 🧪 Testing & Quality Assurance

CombineExt includes comprehensive test coverage with **216+ tests** ensuring reliability and stability:

### Test Coverage
- **Property Wrappers**: `@ManagedState`, `@UIState`, `@UIBinding`, `@ValueSubject`, `@IgnoredState`
- **Dynamic Callable**: All property wrappers with dynamic callable support
- **Publisher Extensions**: `filterNils()`, `mapVoid()`, `CombineLatest5/6`, `Zip5/6`
- **Safe Operations**: Collection access, array operations, bounds checking
- **Thread Safety**: Concurrent access patterns, race condition prevention
- **Edge Cases**: Memory management, performance, error scenarios
- **Result Builders**: `SubscriptionBuilder`, `AnyTokenBuilder` functionality
- **Utility Functions**: `differs()` with comprehensive test coverage
- **Protocol Conformance**: `CustomStringConvertible`, `CustomDebugStringConvertible`, `CustomLocalizedStringResourceConvertible`
- **DiffedValue**: `map(keyPath:)`, `hasChanged(keyPath:)` methods with full testing

### Running Tests
```bash
swift test
```

All tests pass with 100% success rate, ensuring the library is production-ready.

## ✅ Summary

CombineExt simplifies building reactive UIKit applications with a comprehensive set of tools:

- **State Management**: `@ManagedState`, `@UIState`, `@ValueSubject` for different reactive patterns
- **Data Tracking**: `DiffedValue` for state transitions, `@IgnoredState` for transient data
- **Thread Safety**: `withLock` for atomic operations, preventing race conditions in concurrent code
- **Safe Operations**: Safe collection access, nil filtering, and crash prevention
- **Advanced Binding**: Rich binding DSL with both `WritableKeyPath` and `KeyPath` support
- **Extended Publishers**: `CombineLatest5/6`, `Zip5/6` for complex data flows
- **Dynamic Callable**: Intuitive property wrapper syntax for all reactive types
- **Utility Functions**: `differs()` for efficient value comparison with key paths
- **Platform Support**: iOS 16+, macOS 14+, tvOS 16+, watchOS 9+, visionOS 1+
- **Clean Architecture**: Perfect for MVVM/MVI patterns with type-safe, testable code
- **SwiftUI Compatibility**: Works seamlessly with SwiftUI while maintaining UIKit flexibility
- **Comprehensive Testing**: 216+ tests ensuring reliability and stability
- **Full Documentation**: Complete API documentation with examples and thread safety warnings
- **Protocol Conformance**: Full support for `CustomStringConvertible`, `CustomDebugStringConvertible`, and `CustomLocalizedStringResourceConvertible`

## 💬 Contributing

Issues, suggestions, and pull requests are welcome!

## 📄 License

MIT. See the [LICENSE](LICENSE) file for details.
