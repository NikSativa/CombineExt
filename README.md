# CombineExt
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FNikSativa%2FCombineExt%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/NikSativa/CombineExt)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FNikSativa%2FCombineExt%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/NikSativa/CombineExt)

Swift library that provides additional features for Combine framework.

### UIState & UIBinding

`UIState` is a property wrapper that enables reactive state management using Combine. It supports nested property bindings via `UIBinding`, making it ideal for fine-grained updates in MVVM architectures.

```swift
struct State: Equatable {
    var counter: Int
    var toggle: Bool
}

@UIState
var state: State = .init(counter: 0, toggle: false)

// Create a binding to a nested property
let counterBinding = $state.counter

var observedValues: [Int] = []
counterBinding.sink { newValue in
    observedValues.append(newValue)
}.store(in: &observers)

// Mutate the state; this will trigger the binding
state.counter += 1
```

### observe and safe accessors

In addition to dynamic member access, you can create bindings more explicitly using the `observe(_:)` method or safely access elements of a collection using `safe`.

These APIs help keep your reactive code clean and resilient, especially when working with deeply nested models or arrays that might be out of bounds.

#### 📌 observe — Create bindings to nested properties manually

Use `observe(_:)` when you want to explicitly bind to a deeply nested property, like `model.details.age`.

```swift
struct Model {
    var name: String
    var details: Details
}

struct Details {
    var age: Int
}

@UIState var model = Model(name: "Alice", details: .init(age: 30))

let ageBinding = $model.observe(\.details.age)
ageBinding.wrappedValue = 31
```

This snippet shows how to reactively bind to a property several levels deep, so updates to `age` will be observed and propagated.

#### 🛡️ safe — Access array elements without crashing

Swift arrays will crash if you access an out-of-bounds index. The `safe` APIs let you bind to specific elements of an array in a way that gracefully handles invalid indexes.

```swift
@UIState var items: [String?] = ["A", "B"]

let first = $items.safe(0)
print(first.wrappedValue) // "A"

let fallback = $items.safe(5, default: "N/A")
print(fallback.wrappedValue) // "N/A"

let optional = $items.safe(2) // Optional binding (returns nil if out-of-bounds)
print(optional.wrappedValue ?? "None") // "None"
```

These tools help you avoid boilerplate index checks and keep your UI code safe and expressive.

### ValueSubject

`ValueSubject` is a reference type that wraps a value and provides Combine-based publishing and binding. It is especially useful for state sharing in reference-oriented architectures such as UIKit.

```swift
struct State: Equatable {
    var counter: Int
    var toggle: Bool
}

@ValueSubject
var state: State = .init(counter: 0, toggle: false)

// Observe a nested property reactively
let counterSubject = $state.counter

var observedValues: [Int] = []
counterSubject.sink { newValue in
    observedValues.append(newValue)
}.store(in: &observers)

// Update the subject; this will notify all subscribers
state.counter += 1
```
