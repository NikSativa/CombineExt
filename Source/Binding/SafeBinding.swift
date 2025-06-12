import Combine
import Foundation

/// A protocol for publishers that expose bindable and observable state using `DiffedValue`.
///
/// Conforming types allow two-way data binding via `UIBinding` and enable reactive
/// state updates with Combine. The protocol ensures that values can be read and
/// written, and that changes are emitted through Combine publishers.
///
/// Types conforming to `SafeBinding` typically represent some form of reactive state,
/// such as `@ManagedState`, `@UIState`, or custom wrappers that track changes and publish them.
///
/// - Note: `Output` must be `DiffedValue<Value>`, and `Failure` must be `Never`.
///
/// ### Example
/// ```swift
/// struct MyModel: BehavioralStateContract { ... }
/// @ManagedState var state = MyModel()
///
/// $state.justNew().sink { newValue in
///     print("State changed:", newValue)
/// }
/// ```
public protocol SafeBinding where Self: Publisher, Failure == Never, Output == DiffedValue<Value> {
    /// The type of the value being observed and mutated.
    ///
    /// This is the model or state type that the binding operates on.
    associatedtype Value

    /// The current value associated with the binding.
    ///
    /// Use this property to read or write the current state. Writing a new value
    /// triggers observation and notifies any active bindings or observers.
    ///
    /// ### Example
    /// ```swift
    /// @ManagedState var model = MyModel()
    /// $model.wrappedValue = MyModel(updated: true)
    /// print($model.wrappedValue)
    /// ```
    var wrappedValue: Value { get nonmutating set }
}

public extension SafeBinding {
    /// Alias for `justNew(_:)`. Provided for naming flexibility.
    ///
    /// Returns a publisher emitting the new value of a nested property extracted from each `DiffedValue`.
    ///
    /// - Parameter keyPath: A writable key path to the desired property.
    /// - Returns: A publisher emitting the new value at the specified key path.
    ///
    /// ### Example
    /// ```swift
    /// @UIState var state = AppState()
    /// let nestedPublisher = $state.extractNew(\.nestedProperty)
    /// nestedPublisher.sink { newValue in
    ///     print("New nested property value: \(newValue)")
    /// }
    /// ```
    func extractNew<New>(_ keyPath: WritableKeyPath<Value, New>) -> AnyPublisher<New, Failure> {
        return justNew(keyPath)
    }

    /// Returns a publisher emitting the new values of a nested property extracted from each `DiffedValue`.
    ///
    /// - Parameter keyPath: A writable key path from the root value to the nested property.
    /// - Returns: A publisher emitting the new value at the specified key path.
    ///
    /// ### Example
    /// ```swift
    /// @UIState var state = AppState()
    /// let nestedPublisher = $state.justNew(\.nestedProperty)
    /// nestedPublisher.sink { newValue in
    ///     print("New nested property value: \(newValue)")
    /// }
    /// ```
    func justNew<New>(_ keyPath: WritableKeyPath<Value, New>) -> AnyPublisher<New, Failure> {
        return map {
            return $0.new[keyPath: keyPath]
        }.eraseToAnyPublisher()
    }

    /// Returns a publisher emitting the new values of the entire wrapped value.
    ///
    /// - Returns: A publisher emitting the new wrapped value.
    ///
    /// ### Example
    /// ```swift
    /// @UIState var state = AppState()
    /// let newValuePublisher = $state.justNew()
    /// newValuePublisher.sink { newValue in
    ///     print("New state value: \(newValue)")
    /// }
    /// ```
    func justNew() -> AnyPublisher<Value, Failure> {
        return map {
            return $0.new
        }.eraseToAnyPublisher()
    }

    /// Creates a new `UIBinding` for a nested property specified by a writable key path.
    ///
    /// - Parameter keyPath: A writable key path from the current output to a nested value.
    /// - Returns: A new `UIBinding` that reacts to changes in the nested property.
    ///
    /// ### Example
    /// ```swift
    /// @UIState var state = AppState()
    /// let nestedBinding = $state.observe(\.nestedProperty)
    /// nestedBinding.wrappedValue = newValue // Updates nested property
    /// ```
    func observe<New>(_ keyPath: WritableKeyPath<Value, New>) -> UIBinding<New> {
        let newPublisher: AnyPublisher<DiffedValue<New>, Never> = map { parent in
            return DiffedValue(old: parent.old?[keyPath: keyPath], new: parent.$bindableNew.observe(keyPath))
        }
        .eraseToAnyPublisher()

        return .init(publisher: newPublisher) {
            return self.wrappedValue[keyPath: keyPath]
        } set: { [self] new in
            wrappedValue[keyPath: keyPath] = new
        }
    }

    /// Creates a `UIBinding` to the entire wrapped value.
    ///
    /// This is a convenience overload of `observe(_:)` that targets the root value directly.
    ///
    /// - Returns: A `UIBinding` for the entire wrapped value.
    ///
    /// ### Example
    /// ```swift
    /// @UIState var state = AppState()
    /// let binding = $state.observe()
    /// binding.wrappedValue = AppState() // Mutates entire state
    /// ```
    func observe() -> UIBinding<Value> {
        return observe(\.self)
    }
}

/// Extension to `SafeBinding` for publishers whose wrapped value is a mutable collection.
///
/// Provides helpers for accessing or binding to indexed elements safely or unsafely.
public extension SafeBinding where Value: MutableCollection {
    /// Accesses and binds to a collection element at the given index without bounds checking.
    ///
    /// ⚠️ This method will crash at runtime if the index is out of bounds.
    /// Use `safe(_:default:)` for safer access when the index may be invalid.
    ///
    /// - Parameter index: The index of the element to access.
    /// - Returns: A `UIBinding` for the element at the given index.
    ///
    /// ### Example
    /// ```swift
    /// @UIState var list = ["A", "B", "C"]
    /// let second = $list.unsafe(1)
    /// print(second.wrappedValue) // "B"
    /// ```
    func unsafe(_ index: Value.Index) -> UIBinding<Value.Element> {
        let publisher: AnyPublisher<DiffedValue<Value.Element>, Never>? = filter { collection in
            return collection.new.contains(index: index)
        }
        .map { collection in
            return .init(old: collection.old?[safe: index], new: collection.$bindableNew.unsafe(index))
        }
        .eraseToAnyPublisher()

        return UIBinding<Value.Element>(publisher: publisher) {
            let collection = wrappedValue
            if collection.contains(index: index) {
                return collection[index]
            }
            fatalError("should never happen!")
        } set: { newValue in
            var collection = wrappedValue
            if collection.contains(index: index) {
                collection[index] = newValue
                wrappedValue = collection
            } else {
                fatalError("should never happen!")
            }
        }
    }

    /// Safely accesses and binds to a collection element at the given index, with a fallback value.
    ///
    /// When the index is out of bounds, the binding will provide the specified fallback value.
    /// Writes to the binding are no-ops if the index is invalid.
    ///
    /// - Parameters:
    ///   - index: The index of the element to access.
    ///   - defaultValue: A fallback value returned and published when the index is out of bounds.
    /// - Returns: A `UIBinding` for the element at the index, or the fallback value if the index is invalid.
    ///
    /// ### Example
    /// ```swift
    /// @UIState var items: [String] = ["A", "B"]
    /// let third = $items.safe(2, default: "N/A")
    /// print(third.wrappedValue) // "N/A" because index 2 is out of bounds
    /// third.wrappedValue = "S"  // No-op because index 2 is still out of bounds
    /// print(third.wrappedValue) // "N/A" because index 2 is still out of bounds
    /// ```
    func safe(_ index: Value.Index, default defaultValue: @autoclosure @escaping () -> Value.Element) -> UIBinding<Value.Element> {
        let elementPublisher: AnyPublisher<DiffedValue<Value.Element>, Never>? = map { parent in
            guard parent.new.contains(index: index) else {
                return .init(old: defaultValue(), new: .init(get: defaultValue, set: { _ in }))
            }

            return .init(old: parent.old?[safe: index], new: parent.$bindableNew.safe(index, default: defaultValue()))
        }
        .eraseToAnyPublisher()

        return .init(publisher: elementPublisher) {
            let collection = wrappedValue
            return collection.contains(index: index) ? collection[index] : defaultValue()
        } set: { newValue in
            var collection = wrappedValue
            if collection.contains(index: index) {
                collection[index] = newValue
                wrappedValue = collection
            }
        }
    }

    /// Returns a binding to an element at the given index or `nil` when out of bounds.
    ///
    /// This overload is available when the element type conforms to `ExpressibleByNilLiteral`.
    /// When the index is invalid, the binding provides `nil` as a fallback value.
    ///
    /// - Parameter index: The index to bind to.
    /// - Returns: A `UIBinding` for the element at the index or `nil` if out of bounds.
    ///
    /// ### Example
    /// ```swift
    /// @UIState var optionalItems: [String?] = ["A", "B"]
    /// let maybeThird = $optionalItems.safe(2)
    /// print(maybeThird.wrappedValue ?? "None") // "None"
    /// ```
    func safe(_ index: Value.Index) -> UIBinding<Value.Element>
    where Value.Element: ExpressibleByNilLiteral {
        // Returns a binding to an element at the given index or `nil` when out of bounds.
        //
        // - Parameter index: The index to bind to.
        // - Returns: A `UIBinding` for the element at the index or `nil` if out of bounds.
        return safe(index, default: nil)
    }

    /// Returns a binding to an element at the given index or an empty array (`[]`) when out of bounds.
    ///
    /// This overload is available when the element type conforms to `ExpressibleByArrayLiteral`.
    /// When the index is invalid, the binding provides an empty array as a fallback value.
    ///
    /// - Parameter index: The index to bind to.
    /// - Returns: A `UIBinding` for the array element or an empty array if the index is invalid.
    ///
    /// ### Example
    /// ```swift
    /// @UIState var arrayOfArrays: [[Int]] = [[1, 2]]
    /// let outOfBounds = $arrayOfArrays.safe(2)
    /// print(outOfBounds.wrappedValue) // []
    /// ```
    func safe(_ index: Value.Index) -> UIBinding<Value.Element>
    where Value.Element: ExpressibleByArrayLiteral {
        return safe(index, default: [])
    }

    /// Returns a binding to an element at the given index or an empty dictionary (`[:]`) when out of bounds.
    ///
    /// This overload is available when the element type conforms to `ExpressibleByDictionaryLiteral`.
    /// When the index is invalid, the binding provides an empty dictionary as a fallback value.
    ///
    /// - Parameter index: The index to bind to.
    /// - Returns: A `UIBinding` for the dictionary element or an empty dictionary if the index is invalid.
    ///
    /// ### Example
    /// ```swift
    /// @UIState var arrayOfDicts: [[String: Int]] = [["one": 1]]
    /// let outOfBounds = $arrayOfDicts.safe(2)
    /// print(outOfBounds.wrappedValue) // [:]
    /// ```
    func safe(_ index: Value.Index) -> UIBinding<Value.Element>
    where Value.Element: ExpressibleByDictionaryLiteral {
        return safe(index, default: [:])
    }

    /// Returns a binding to an element at the given index or `0.0` when out of bounds.
    ///
    /// This overload is available when the element type conforms to `ExpressibleByFloatLiteral`.
    /// When the index is invalid, the binding provides `0.0` as a fallback value.
    ///
    /// - Parameter index: The index to bind to.
    /// - Returns: A `UIBinding` for the floating-point element or `0.0` if the index is invalid.
    ///
    /// ### Example
    /// ```swift
    /// @UIState var arrayOfFloats: [Double] = [1.5, 2.5]
    /// let outOfBounds = $arrayOfFloats.safe(3)
    /// print(outOfBounds.wrappedValue) // 0.0
    /// ```
    func safe(_ index: Value.Index) -> UIBinding<Value.Element>
    where Value.Element: ExpressibleByFloatLiteral {
        return safe(index, default: 0.0)
    }

    /// Returns a binding to an element at the given index or an empty string (`""`) when out of bounds.
    ///
    /// This overload is available when the element type conforms to `ExpressibleByStringLiteral`.
    /// When the index is invalid, the binding provides an empty string as a fallback value.
    ///
    /// - Parameter index: The index to bind to.
    /// - Returns: A `UIBinding` for the string element or an empty string if the index is invalid.
    ///
    /// ### Example
    /// ```swift
    /// @UIState var arrayOfStrings: [String] = ["Hello", "World"]
    /// let outOfBounds = $arrayOfStrings.safe(5)
    /// print(outOfBounds.wrappedValue) // ""
    /// ```
    func safe(_ index: Value.Index) -> UIBinding<Value.Element>
    where Value.Element: ExpressibleByStringLiteral {
        return safe(index, default: "")
    }

    /// Returns a binding to an element at the given index or `0` when out of bounds.
    ///
    /// This overload is available when the element type conforms to `ExpressibleByIntegerLiteral`.
    /// When the index is invalid, the binding provides `0` as a fallback value.
    ///
    /// - Parameter index: The index to bind to.
    /// - Returns: A `UIBinding` for the integer element or `0` if the index is invalid.
    ///
    /// ### Example
    /// ```swift
    /// @UIState var arrayOfInts: [Int] = [1, 2, 3]
    /// let outOfBounds = $arrayOfInts.safe(10)
    /// print(outOfBounds.wrappedValue) // 0
    /// ```
    func safe(_ index: Value.Index) -> UIBinding<Value.Element>
    where Value.Element: ExpressibleByIntegerLiteral {
        return safe(index, default: 0)
    }
}
