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

    /// Binds changes to a specific property and reacts with a curried closure.
    ///
    /// This method detects changes at the specified key path and passes the parent model
    /// into a closure that returns another closure handling the property's new value.
    ///
    /// - Parameters:
    ///   - keyPath: A key path to the value being observed.
    ///   - onChange: A curried closure taking the model and new value.
    /// - Returns: A cancellable instance managing the binding.
    ///
    /// ### Example
    /// ```swift
    /// publisher.bind(to: \.name, onChange: Value.onChangeNew(_:))
    /// ```
    func bind<Value, NEW>(to keyPath: WritableKeyPath<Value, NEW>,
                          onChange: @escaping (Value) -> (NEW) -> Void) -> Cancellable
    where Value: BehavioralStateContract, Output == DiffedValue<Value>, NEW: Equatable {
        filter { parent in
            return parent.old?[keyPath: keyPath] != parent.new[keyPath: keyPath]
        }
        .sink { parent in
            onChange(parent.new)(parent.new[keyPath: keyPath])
        }
    }

    /// Binds changes to a specific property and triggers a deferred closure.
    ///
    /// This form allows logic to execute after property changes without arguments.
    ///
    /// - Parameters:
    ///   - keyPath: The path to the property being tracked.
    ///   - onChange: A closure returning another closure executed upon change.
    /// - Returns: A cancellable binding subscription.
    ///
    /// ### Example
    /// ```swift
    /// publisher.bind(to: \.name, onChange: Value.onChangeNew)
    /// ```
    func bind<Value>(to keyPath: WritableKeyPath<Value, some Equatable>,
                     onChange: @escaping (Value) -> () -> Void) -> Cancellable
    where Value: BehavioralStateContract, Output == DiffedValue<Value> {
        filter { parent in
            return parent.old?[keyPath: keyPath] != parent.new[keyPath: keyPath]
        }
        .sink { parent in
            onChange(parent.new)()
        }
    }

    func bind<Value, NEW>(to keyPath: WritableKeyPath<Value, NEW>,
                          onChange: @escaping (inout Value, NEW) -> Void) -> Cancellable
    where Value: BehavioralStateContract, Output == DiffedValue<Value>, NEW: Equatable {
        filter { parent in
            return parent.old?[keyPath: keyPath] != parent.new[keyPath: keyPath]
        }
        .sink { parent in
            onChange(&parent.new, parent.new[keyPath: keyPath])
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

    /// Binds changes to a nested value and provides the full diff to a mutating closure.
    ///
    /// This method provides both old and new values of a property to a closure that
    /// mutates the parent model based on the change.
    ///
    /// - Parameters:
    ///   - keyPath: A writable key path to a nested value.
    ///   - onChange: A closure that mutates the parent using the value diff.
    /// - Returns: A cancellable instance for the binding.
    ///
    /// ### Example
    /// ```swift
    /// publisher.bindDiffed(to: \.title) { model, titleDiff in
    ///     model.subtitle = "Changed from \(titleDiff.old ?? "") to \(titleDiff.new)"
    /// }
    /// ```
    func bindDiffed<Value, NEW>(to keyPath: WritableKeyPath<Value, NEW>,
                                onChange: @escaping (inout Value, DiffedValue<NEW>) -> Void) -> Cancellable
    where Value: BehavioralStateContract, Output == DiffedValue<Value>, NEW: Equatable {
        filter { parent in
            return parent.old?[keyPath: keyPath] != parent.new[keyPath: keyPath]
        }
        .sink { parent in
            let new = DiffedValue(old: parent.old?[keyPath: keyPath], new: parent.$bindableNew.observe(keyPath))
            onChange(&parent.new, new)
        }
    }
}
