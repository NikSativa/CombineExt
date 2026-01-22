import Combine
import Foundation

/// A protocol that defines the reactive state and event rules for a model managed by `ManagedState`.
///
/// Conforming types define how a model interacts with the UI and external systems through Combine bindings and notifications.
/// This protocol is typically used in MVVM or unidirectional data flow architectures.
///
/// Use `applyBindingRules(to:)` to bind view updates and side effects to state changes.
/// Use `applyAnyRules(to:)` to handle external events, such as system notifications or app lifecycle changes.
///
/// All types conforming to this protocol must also conform to `Equatable`.
public protocol BehavioralStateContract: Equatable {
    /// A publisher that emits `DiffedValue` changes for the conforming model.
    ///
    /// Used as the primary input to binding rules, representing observable state changes.
    ///
    /// ### Example
    /// ```swift
    /// typealias RulesPublisher = AnyPublisher<DiffedValue<MyState>, Never>
    /// ```
    typealias RulesPublisher = AnyPublisher<DiffedValue<Self>, Never>

    /// Applies internal business logic and local transformations to the model’s state.
    ///
    /// This method is called after state mutations to enforce additional rules,
    /// such as validation, auto-corrections, or computed values.
    ///
    /// ### Example
    /// ```swift
    /// mutating func applyRules() {
    ///     if count < 0 { count = 0 }
    /// }
    /// ```
    mutating func applyRules()

    /// Provides a fallback binding rule set for types that do not require reactive pipelines.
    /// This implementation returns an empty array and may be customized by conforming types.
    ///
    /// - Parameter state: A publisher emitting diffs of the model's state.
    /// - Returns: An empty array of cancellables.
    ///
    /// ### Example
    /// ```swift
    /// struct SimpleModel: BehavioralStateContract {
    ///     func applyRules() {}
    /// }
    /// // `applyBindingRules` returns []
    /// ```
    @SubscriptionBuilder
    static func applyBindingRules(to state: RulesPublisher) -> [AnyCancellable]

    /// Applies global event or notification listeners to the model.
    ///
    /// Use this method to observe external inputs such as lifecycle events, push notifications,
    /// or system broadcasts, and react accordingly.
    ///
    /// - Parameter state: A binding proxy to the current model value.
    /// - Returns: An array of observer tokens or cancellables.
    ///
    /// ### Example
    /// ```swift
    /// struct AppLifecycleModel: BehavioralStateContract {
    ///     mutating func applyRules() {}
    ///     @SubscriptionBuilder
    ///     static func applyBindingRules(to state: RulesPublisher) -> [AnyCancellable] { [] }
    ///
    ///     @AnyTokenBuilder<Any>
    ///     static func applyAnyRules(to state: UIBinding<Self>) -> [Any] {
    ///         [
    ///             NotificationCenter.default
    ///                 .publisher(for: UIApplication.didBecomeActiveNotification)
    ///                 .sink { _ in print("App became active") }
    ///         ]
    ///     }
    /// }
    /// ```
    @AnyTokenBuilder<Any>
    static func applyAnyRules(to state: UIBinding<Self>) -> [Any]
}

/// Extension for Combine publishers that emit `DiffedValue` representing changes to a model.
///
/// Enables propagation of binding logic to nested models conforming to `BehavioralStateContract`.
public extension Publisher where Failure == Never {
    /// Applies nested binding rules to a property of the current model.
    ///
    /// This method observes a nested property of the parent model that conforms to `BehavioralStateContract`,
    /// and delegates binding logic to the child model.
    ///
    /// - Parameter keyPath: A writable key path to the nested value.
    /// - Returns: An array of cancellables managing the subscriptions.
    ///
    /// ### Example
    /// ```swift
    /// state.applyNestedRules(to: \.settings)
    /// ```
    @SubscriptionBuilder
    func applyNestedRules<Value, NEW>(to keyPath: WritableKeyPath<Value, NEW>) -> [AnyCancellable]
    where NEW: BehavioralStateContract, Value: BehavioralStateContract, Output == DiffedValue<Value> {
        let state: AnyPublisher<DiffedValue<NEW>, Never> = map { parent in
            return parent.map(keyPath: keyPath)
        }.eraseToAnyPublisher()

        NEW.applyBindingRules(to: state)
    }
}

/// Extension for `UIBinding` to enable composition of notification-based rules.
public extension UIBinding where Value: BehavioralStateContract {
    /// Applies nested event rules to a property of the current model.
    ///
    /// This method enables a child model to register its own notification listeners by delegating rules.
    ///
    /// - Parameter keyPath: A writable key path to the nested value within the parent model.
    /// - Returns: An array of notification tokens managed by the child model.
    ///
    /// ### Example
    /// ```swift
    /// binding.applyNestedRules(to: \.profile)
    /// ```
    @AnyTokenBuilder<Any>
    func applyNestedRules<NEW>(to keyPath: WritableKeyPath<Value, NEW>) -> [Any]
    where NEW: BehavioralStateContract {
        let state: UIBinding<NEW> = observe(keyPath)
        NEW.applyAnyRules(to: state)
    }
}

/// Extends `Optional` to conform to `BehavioralStateContract` when its wrapped type does.
///
/// This enables optional submodels to participate in rule-based state updates and notification handling.
/// Nested `nil` values are treated as no-ops, allowing safe propagation in model hierarchies.
extension Optional: BehavioralStateContract where Wrapped: BehavioralStateContract {
    /// Applies internal business logic and local transformations to the optional model’s state.
    ///
    /// When the optional value is `nil`, this method performs no operation.
    /// This enables optional nested states to conform to `BehavioralStateContract` and participate
    /// in binding and notification flows when non-nil.
    ///
    /// ### Example
    /// ```swift
    /// var child: ChildModel? = nil
    /// child?.applyRules() // safe to call, no-op
    /// ```
    public func applyRules() {}

    /// A default implementation of binding rules for optional types.
    ///
    /// When the optional value is `nil`, no binding rules are applied.
    ///
    /// - Parameter state: A publisher that emits diffs for the optional wrapped model.
    /// - Returns: An empty array when the wrapped value is `nil`.
    @SubscriptionBuilder
    public static func applyBindingRules(to state: RulesPublisher) -> [AnyCancellable] {}

    /// A default implementation of notification rules for optional types.
    ///
    /// When the optional value is `nil`, no rules are applied.
    ///
    /// - Parameter state: A binding for the optional wrapped model.
    /// - Returns: An empty array when the wrapped value is `nil`.
    @AnyTokenBuilder<Any>
    public static func applyAnyRules(to state: UIBinding<Wrapped?>) -> [Any] {}

    /// Compares two optional models for equality.
    ///
    /// Returns `true` if both are `nil` or if both are non-nil and their wrapped values are equal.
    ///
    /// - Parameters:
    ///   - lhs: A left-hand side optional model.
    ///   - rhs: A right-hand side optional model.
    /// - Returns: `true` if the values are equivalent.
    ///
    /// ### Example
    /// ```swift
    /// let a: MyModel? = MyModel()
    /// let b: MyModel? = MyModel()
    /// let isEqual = a == b
    /// ```
    public static func ==(lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none):
            return true
        case (.some(let lhs), .some(let rhs)):
            return lhs == rhs
        default:
            return false
        }
    }
}
