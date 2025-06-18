import Combine
import Foundation

/// A protocol that combines a bindable property interface with Combine's `Publisher` interface.
///
/// `SafeBinding` allows clients to observe and react to changes in a wrapped value through a `Publisher`,
/// while also providing access to the current value via `wrappedValue`. It is typically used
/// with property wrappers such as `@UIState` or `@ManagedState` to support reactive UIs.
///
/// Conforming types must emit `DiffedValue` objects representing both old and new values.
///
/// ### Conformance Requirements
/// - Must be a Combine `Publisher` with `Output == DiffedValue<Value>` and `Failure == Never`.
/// - Must support getting and setting the `wrappedValue`.
/// - Must conform to `CustomReflectable`.
///
/// ### Example
/// ```swift
/// @ManagedState var name = "Initial"
///
/// $name.justNew().sink { newValue in
///     print("New value is", newValue)
/// }
/// ```
public protocol SafeBinding: CustomReflectable
where Self: Publisher, Failure == Never, Output == DiffedValue<Value> {
    /// The type of the underlying value being observed and mutated.
    ///
    /// Conforming types use `Value` to represent the state or model exposed via this binding.
    associatedtype Value

    /// Accesses the current value of the binding.
    ///
    /// You can read the current value or assign a new one. Assigning a new value emits a `DiffedValue`
    /// containing both the previous and new values.
    ///
    /// ### Example
    /// ```swift
    /// @UIState var count = 0
    /// $count.wrappedValue += 1
    /// print($count.wrappedValue)
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
            return DiffedValue(old: parent.old?[keyPath: keyPath], new: parent.$bindableNew(keyPath))
        }
        .eraseToAnyPublisher()

        return .init(publisher: newPublisher) { [self] in
            return wrappedValue[keyPath: keyPath]
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

    /// CustomReflectable conformance.
    ///
    /// Provides a mirror reflecting the wrapped value.
    var customMirror: Mirror {
        return .init(reflecting: wrappedValue)
    }
}

/// Extension to `SafeBinding` for publishers whose wrapped value is a mutable collection.
///
/// Provides helpers for accessing or binding to indexed elements safely or unsafely.
public extension SafeBinding where Value: MutableCollection {
    /// Creates an array of `UIBinding` elements corresponding to each index in the wrapped collection.
    ///
    /// This method safely maps each valid index to a binding using `safe(_:default:)`.
    ///
    /// - Returns: An array of `UIBinding` values, one for each index in the collection.
    ///
    /// ### Example
    /// ```swift
    /// @UIState var items = ["A", "B", "C"]
    /// let bindings = $items.bindingArray()
    /// bindings[1].wrappedValue = "Updated"
    /// print($items.wrappedValue[1]) // "Updated"
    /// ```
    func bindingArray() -> [UIBinding<Value.Element>] {
        return wrappedValue.indices.map { idx in
            return safe(idx, default: wrappedValue[idx])
        }
    }

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

    /// Safely accesses and binds to a collection element at the given index.
    ///
    /// This overload uses the current value at the index as the default value.
    ///
    /// ⚠️ This method will crash if the index is out of bounds.
    /// Consider using `safe(_:default:)` when the index may be invalid.
    ///
    /// - Parameter index: The index of the element to access.
    /// - Returns: A `UIBinding` for the element at the given index.
    ///
    /// ### Example
    /// ```swift
    /// @UIState var list = ["X", "Y"]
    /// let binding = $list.safe(1)
    /// print(binding.wrappedValue) // "Y"
    /// ```
    func safe(_ index: Value.Index) -> UIBinding<Value.Element> {
        return safe(index, default: wrappedValue[index])
    }
}
