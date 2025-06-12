import Combine

/// An extension to Combine's `Publisher` where `Failure` is `Never` and `Output` is a `DiffedValue`.
///
/// This extension provides utilities for binding and observing state changes using `DiffedValue`,
/// which is commonly used in reactive UI or state management scenarios.
public extension Publisher where Failure == Never {
    /// Subscribes to a publisher that emits `DiffedValue` and receives only the new value.
    ///
    /// This method maps each emitted `DiffedValue` to its `new` value and invokes the provided closure with it.
    ///
    /// - Parameter block: A closure to execute with the new value.
    /// - Returns: A cancellable instance representing the subscription.
    ///
    /// - Example:
    /// ```swift
    /// publisher.sink { (newValue: Int) in
    ///     print("New value: \(newValue)")
    /// }
    /// ```
    func sink<Value>(receiveValue block: @escaping (Value) -> Void) -> AnyCancellable
    where Output == DiffedValue<Value> {
        return map(\.new).sink(receiveValue: block)
    }

    /// Subscribes to a publisher that emits `DiffedValue` and runs a closure on each update, ignoring the emitted value.
    ///
    /// This overload is useful for triggering side effects without needing the emitted value.
    ///
    /// - Parameter block: A closure to execute whenever a value is emitted.
    /// - Returns: A cancellable instance representing the subscription.
    ///
    /// - Example:
    /// ```swift
    /// publisher.sink {
    ///     print("Something changed")
    /// }
    /// ```
    func sink<Value>(receiveValue block: @escaping () -> Void) -> AnyCancellable
    where Output == DiffedValue<Value> {
        return sink { _ in
            block()
        }
    }

    /// Binds changes to a nested property and mutates the property directly.
    ///
    /// Emits only when the property at the specified key path changes, then allows
    /// mutation of the nested value via the provided closure.
    ///
    /// - Parameters:
    ///   - keyPath: A writable key path to the nested property.
    ///   - onChange: Closure used to mutate the nested value.
    /// - Returns: A cancellable object for managing the subscription.
    ///
    /// - Example:
    /// ```swift
    /// publisher.bind(to: \.profile.name) { name in
    ///     name = "Updated Name"
    /// }
    /// ```
    func bind<S, Value>(to keyPath: WritableKeyPath<Value, S>,
                        onChange: @escaping (inout S) -> Void) -> Cancellable
    where S: Equatable, Value: BehavioralStateContract, Output == DiffedValue<Value> {
        map { parent in
            return DiffedValue(old: parent.old?[keyPath: keyPath], new: parent.$bindableNew.observe(keyPath))
        }
        .removeDuplicates()
        .sink { parent in
            var new = parent.new
            onChange(&new)
            parent.new = new
        }
    }

    /// Binds changes to a nested property and mutates the parent model in response.
    ///
    /// This version compares old and new values at the key path before invoking the mutation.
    /// It is useful for propagating nested property changes to the parent model.
    ///
    /// - Parameters:
    ///   - keyPath: A writable key path to the property to track.
    ///   - onChange: Closure to mutate the parent model.
    /// - Returns: A cancellable managing the binding.
    ///
    /// - Example:
    /// ```swift
    /// publisher.bind(to: \.settings.theme) { parent in
    ///     parent.updateTheme(to: .dark)
    /// }
    /// ```
    func bind<Value>(to keyPath: WritableKeyPath<Value, some Equatable>,
                     onChange: @escaping (inout Value) -> Void) -> Cancellable
    where Value: BehavioralStateContract, Output == DiffedValue<Value> {
        filter { parent in
            return parent.old?[keyPath: keyPath] != parent.new[keyPath: keyPath]
        }
        .sink { parent in
            onChange(&parent.new)
        }
    }

    /// Binds changes to the entire model by mutating it in response to each update.
    ///
    /// - Parameter onChange: A closure that modifies the entire model.
    /// - Returns: A cancellable subscription managing the binding.
    ///
    /// - Example:
    /// ```swift
    /// publisher.bind { model in
    ///     model.flag.toggle()
    /// }
    /// ```
    func bind<Value>(onChange: @escaping (inout Value) -> Void) -> Cancellable
    where Value: BehavioralStateContract, Output == DiffedValue<Value> {
        sink { parent in
            var value = parent.new
            onChange(&value)
            parent.new = value
        }
    }

    /// Binds using the full `DiffedValue` and performs a transformation.
    ///
    /// Emits the entire change object to the closure for custom handling.
    ///
    /// - Parameter onChange: A closure that processes the full `DiffedValue`.
    /// - Returns: A cancellable subscription managing the binding.
    func bindDiffed<Value>(onChange: @escaping (DiffedValue<Value>) -> Void) -> Cancellable
    where Value: BehavioralStateContract, Output == DiffedValue<Value> {
        sink { parent in
            onChange(parent)
        }
    }

    /// Binds changes at a given key path using the full `DiffedValue`.
    ///
    /// Filters changes using the provided key path and invokes the closure with the entire diffed model.
    ///
    /// - Parameters:
    ///   - keyPath: Key path to a tracked `Equatable` property.
    ///   - onChange: Closure to handle the change.
    /// - Returns: A cancellable subscription managing the binding.
    func bindDiffed<Value>(to keyPath: WritableKeyPath<Value, some Equatable>,
                           onChange: @escaping (DiffedValue<Value>) -> Void) -> Cancellable
    where Value: BehavioralStateContract, Output == DiffedValue<Value> {
        filter { parent in
            return parent.old?[keyPath: keyPath] != parent.new[keyPath: keyPath]
        }
        .sink { parent in
            onChange(parent)
        }
    }
}
