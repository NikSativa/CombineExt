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
/// All types conforming to this protocol must also conform to `Equatable` and `ActionHandling`.
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

    /// A no-op default implementation of ``applyBindingRules(to:)``.
    ///
    /// Provides a fallback binding rule set for types that do not require reactive pipelines.
    /// This implementation returns an empty array and can be overridden by conforming types.
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

    /// A no-op default implementation of ``applyAnyRules(to:)``.
    ///
    /// Provides a fallback set of tokens for types that do not need external event handling.
    ///
    /// - Parameter state: A binding to the current model state.
    /// - Returns: An empty array of tokens.
    ///
    /// ### Example
    /// ```swift
    /// struct StatelessModel: BehavioralStateContract {
    ///     func applyRules() {}
    /// }
    /// // `applyAnyRules` returns []
    /// ```
    @AnyTokenBuilder<Any>
    static func applyAnyRules(to state: UIBinding<Self>) -> [Any]
}

public extension BehavioralStateContract {
    @SubscriptionBuilder
    static func applyBindingRules(to state: RulesPublisher) -> [AnyCancellable] {}

    @AnyTokenBuilder<Any>
    static func applyAnyRules(to state: UIBinding<Self>) -> [Any] {}
}

/// Extension for Combine publishers that emit `DiffedValue` representing changes to a model.
///
/// Enables propagation of binding logic to nested models conforming to `BehavioralStateContract`.
public extension Publisher where Failure == Never {
    /// Applies nested binding rules to a property of the current model.
    ///
    /// This method maps state changes of a composite model to its child, allowing the child
    /// to apply its own Combine-based bindings.
    ///
    /// - Parameter keyPath: A key path to the nested value within the parent model.
    /// - Returns: An array of `AnyCancellable` that manages the subscriptions.
    ///
    /// ### Example
    /// ```swift
    /// state.applyNestedRules(to: \.settings)
    /// ```
    @SubscriptionBuilder
    func applyNestedRules<Value, NEW>(to keyPath: WritableKeyPath<Value, NEW>) -> [AnyCancellable]
    where NEW: BehavioralStateContract, Value: BehavioralStateContract, Output == DiffedValue<Value> {
        let state: AnyPublisher<DiffedValue<NEW>, Never> = map { parent in
            return DiffedValue(old: parent.old?[keyPath: keyPath], new: parent.$bindableNew.observe(keyPath))
        }.eraseToAnyPublisher()

        NEW.applyBindingRules(to: state)
    }
}

/// Extension for `UIBinding` to enable composition of notification-based rules.
public extension UIBinding where Value: BehavioralStateContract {
    /// Applies nested event rules to a property of the current model.
    ///
    /// This method connects notification logic from a child value, allowing side effects
    /// to be handled at a nested level.
    ///
    /// - Parameter keyPath: A writable key path from the parent model to the nested value.
    /// - Returns: An array of observer tokens from the child model.
    ///
    /// ### Example
    /// ```swift
    /// binding.applyNestedRules(for: \.profile)
    /// ```
    @AnyTokenBuilder<Any>
    func applyNestedRules<NEW>(for keyPath: WritableKeyPath<Value, NEW>) -> [Any]
    where NEW: BehavioralStateContract {
        let state: UIBinding<NEW> = observe(keyPath)
        NEW.applyAnyRules(to: state)
    }
}

/// Makes optional types conform to `BehavioralStateContract` when their wrapped type does.
///
/// This allows optional submodels to participate in binding and notification rules
/// as long as they are not `nil`.
///
/// This is useful in hierarchical or compositional state trees.
extension Optional: BehavioralStateContract where Wrapped: BehavioralStateContract {
    /// A no-op implementation of ``applyRules()`` for optional values.
    ///
    /// This enables optional nested states to conform to ``BehavioralStateContract``.
    public func applyRules() {}

    /// A no-op implementation of binding rules for optional types.
    ///
    /// This is required to conform `Optional<Wrapped>` to `BehavioralStateContract`.
    @SubscriptionBuilder
    public static func applyBindingRules(to state: RulesPublisher) -> [AnyCancellable] {}

    /// A no-op implementation of generalized notification rules for optional types.
    ///
    /// Returns an empty rule set when no wrapped value exists.
    @AnyTokenBuilder<Any>
    public static func applyAnyRules(to state: UIBinding<Wrapped?>) -> [Any] {}

    /// Compares two optional models for equality.
    ///
    /// Returns `true` if both are `nil` or their wrapped values are equal.
    ///
    /// This allows ``Optional<Wrapped>`` to conform to ``Equatable`` when `Wrapped` does.
    ///
    /// - Parameters:
    ///   - lhs: A left-hand side optional value.
    ///   - rhs: A right-hand side optional value.
    /// - Returns: `true` if both are `nil`, or if both are non-`nil` and their wrapped values are equal.
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
