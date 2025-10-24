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
- **Comprehensive Testing**: 156+ tests ensuring reliability and stability

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

### Dynamic Callable Support

`@UIState` and `@UIBinding` support dynamic callable syntax via projected value:

```swift
@UIState var state = ViewState(isOn: false)

// Access entire value (using $ projected value)
let binding = $state() // Returns binding to entire ViewState

// Access specific properties (using $ projected value)
let isOnBinding = $state(\.isOn) // Returns binding to isOn property

// Update through bindings
isOnBinding.wrappedValue = true
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

### Dynamic Callable Support

`@ValueSubject` supports dynamic callable syntax via projected value:

```swift
struct User {
    var name: String = "John"
    var age: Int = 25
}

@ValueSubject var user = User()

// Access entire value (using $ projected value)
let binding = $user() // Returns binding to entire User struct

// Access specific properties (using $ projected value)
let nameBinding = $user(\.name) // Returns binding to name property
let ageBinding = $user(\.age)   // Returns binding to age property

// Update through bindings
nameBinding.wrappedValue = "Jane"
ageBinding.wrappedValue = 30
```

## 🎯 `@IgnoredState` for Transient Data

Use `@IgnoredState` to wrap values that should not affect equality or hashing:

```swift
struct ViewModel: Equatable {
    var title: String = "Hello"
    @IgnoredState var cache = DataCache()
    @IgnoredState var timer: Timer?
    
    // Only `title` affects equality, `cache` and `timer` are ignored
}

let vm1 = ViewModel()
let vm2 = ViewModel()
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
struct User { var name: String; var age: Int }
@UIState var user = User(name: "Alice", age: 30)

$user.publisher
    .sink { diff in
        diff.name = "Updated Name" // Direct property access
        print("Age: \(diff.age)")
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
// Bind to specific property changes (WritableKeyPath)
state.bind(to: \.username) { model in
    model.lastUpdated = Date()
}

// Bind with both old and new values (WritableKeyPath)
state.bindDiffed(to: \.count) { model, diff in
    print("Count changed from \(diff.old ?? 0) to \(diff.new)")
}

// Bind to nested properties (WritableKeyPath)
state.bind(to: \.profile.name) { name in
    name = name.uppercased()
}

// Read-only bindings (KeyPath) - for observing without modification
state.bind(to: \.readOnlyProperty) { value in
    print("Read-only property changed to: \(value)")
}

// Read-only diffed bindings (KeyPath)
state.bindDiffed(to: \.computedProperty) { model, diff in
    print("Computed property changed from \(diff.old ?? "nil") to \(diff.new)")
}
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
func observeState<T>(_ binding: SafeBinding<T>) {
    binding.justNew()
        .sink { newValue in
            print("New value: \(newValue)")
        }
        .store(in: &cancellables)
}

// Works with any binding type
observeState($uiState)
observeState($managedState)
observeState($valueSubject)
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
        $state.publisher
            .sink { diff in
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

    override func viewDidLoad() {
        super.viewDidLoad()
        setupBindings()
    }
    
    private func setupBindings() {
        // Observe status changes
        viewModel.$state.status
            .sink { [weak self] status in
                self?.statusLabel.text = status
            }
            .store(in: &bag)
            
        // Observe username changes with diff
        viewModel.$state.publisher
            .bindDiffed(to: \.username) { [weak self] model, diff in
                self?.usernameField.text = diff.new
                print("Username changed from '\(diff.old ?? "")' to '\(diff.new)'")
            }
            .store(in: &bag)
            
        // Safe array access for validation messages
        let validationMessages = ["Username required", "Password too short", "Invalid email"]
        let messageBinding = $validationMessages.safe(0, default: "No message")
        messageBinding.wrappedValue = "Ready to validate"
    }
    
    @IBAction func usernameChanged(_ sender: UITextField) {
        viewModel.state.username = sender.text ?? ""
    }
    
    @IBAction func passwordChanged(_ sender: UITextField) {
        viewModel.state.password = sender.text ?? ""
    }
}
```

## 📱 Platform Support

CombineExt supports all major Apple platforms:

- **iOS 13+** - Full support for UIKit reactive patterns
- **macOS 11+** - AppKit and SwiftUI compatibility  
- **tvOS 13+** - tvOS interface development
- **watchOS 6+** - Watch app state management
- **visionOS 1+** - Vision Pro app development
- **macCatalyst 13+** - iPad apps on Mac

## 🔧 Advanced Configuration

### ManagedState Locking

```swift
// Thread-safe (default)
@ManagedState var state = MyState()

// No locking for single-threaded contexts
@ManagedState(lock: .absent) var state = MyState()

// Custom lock
@ManagedState(lock: .custom(NSRecursiveLock())) var state = MyState()
```

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
@ManagedState var counter = CounterModel()

// Atomic increment
counter.withLock { value in
    value.count += 1
    value.lastUpdated = Date()
}

// Complex atomic operations
counter.withLock { value in
    value.count += 1
    value.isEven = value.count % 2 == 0
    value.displayText = "Count: \(value.count)"
}
```

### Cyclic Dependency Detection

```swift
// Disable warnings in tests
ManagedStateCyclicDependencyWarning = false
ManagedStateCyclicDependencyMaxDepth = 50
```

## 🧪 Testing & Quality Assurance

CombineExt includes comprehensive test coverage with **156+ tests** ensuring reliability and stability:

### Test Coverage
- **Property Wrappers**: `@ManagedState`, `@UIState`, `@UIBinding`, `@ValueSubject`, `@IgnoredState`
- **Dynamic Callable**: All property wrappers with dynamic callable support
- **Publisher Extensions**: `filterNils()`, `mapVoid()`, `CombineLatest5/6`, `Zip5/6`
- **Safe Operations**: Collection access, array operations, bounds checking
- **Thread Safety**: Concurrent access patterns, race condition prevention
- **Edge Cases**: Memory management, performance, error scenarios
- **Result Builders**: `SubscriptionBuilder`, `AnyTokenBuilder` functionality

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
- **Platform Support**: iOS 13+, macOS 11+, tvOS 13+, watchOS 6+, visionOS 1+
- **Clean Architecture**: Perfect for MVVM/MVI patterns with type-safe, testable code
- **SwiftUI Compatibility**: Works seamlessly with SwiftUI while maintaining UIKit flexibility
- **Comprehensive Testing**: 156+ tests ensuring reliability and stability
- **Full Documentation**: Complete API documentation with examples and thread safety warnings

## 💬 Contributing

Issues, suggestions, and pull requests are welcome!

## 📄 License

MIT. See the [LICENSE](LICENSE) file for details.
