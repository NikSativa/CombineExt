import Combine
import Foundation

/// A protocol that defines the reactive state and event rules for a model managed by `ManagedState`.
///
/// Conforming types define how a model interacts with the UI and external systems through Combine bindings and notifications.
/// This protocol is typically used in MVVM or unidirectional data flow architectures.
///
/// Use `applyBindingRules(for:to:)` to bind view updates and side effects to state changes.
/// Use `applyNotificationRules(to:)` to handle external events, such as system notifications or app lifecycle changes.
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

    /// Sets up Combine bindings between the model’s state and an action receiver.
    ///
    /// Called automatically by `ManagedState` during initialization. Use this to connect
    /// published state properties and event-driven Combine pipelines that produce actions.
    ///
    /// - Parameters:
    ///   - state: A binding wrapper that enables observation and mutation of the model’s state.
    ///   - receiver: A subject that accepts actions from the UI or external sources.
    /// - Returns: An array of `AnyCancellable` instances that manage the lifecycle of the bindings.
    @SubscriptionBuilder
    static func applyBindingRules(to state: RulesPublisher) -> [AnyCancellable]

    /// Sets up notification-based rules that trigger actions in response to external events.
    ///
    /// This can be used to observe app lifecycle events, system notifications, or any other publishers that emit non-UI events.
    ///
    /// - Parameter actionReceiver: A closure that dispatches actions in response to notifications.
    /// - Returns: An array of `NotificationToken` instances used to manage the lifetime of the observers.
    @NotificationBuilder
    static func applyNotificationRules(to state: UIBinding<Self>) -> [NotificationToken]
}

/// Extension for Combine publishers that emit `DiffedValue` representing changes to a model.
///
/// Enables propagation of binding logic to nested models conforming to `BehavioralStateContract`.
public extension Publisher where Failure == Never {
    /// Applies nested binding logic for a child model conforming to `BehavioralStateContract`.
    ///
    /// Useful when composing complex state hierarchies, where child models also define their own binding rules.
    ///
    /// - Parameters:
    ///   - keyPath: A writable key path to the nested model.
    /// - Returns: An array of cancellables for managing the nested Combine pipelines.
    ///
    /// ### Example
    /// ```swift
    /// struct ParentState: BehavioralStateContract {
    ///     var child: ChildState
    ///
    ///     static func applyBindingRules(to state: RulesPublisher) -> [AnyCancellable] {
    ///         state.applyNestedRules(to: \.child)
    ///     }
    /// }
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
    /// Applies nested notification rules for a child model.
    ///
    /// Forwards notifications and events down to optional or nested child states.
    ///
    /// - Parameters:
    ///   - keyPath: A key path to the child state.
    /// - Returns: An array of notification tokens to manage the observers.
    ///
    /// ### Example
    /// ```swift
    /// struct ParentState: BehavioralStateContract {
    ///     var child: ChildState
    ///
    ///     static func applyNotificationRules(to state: UIBinding<Self>) -> [NotificationToken] {
    ///         state.applyNestedRules(for: \.child)
    ///     }
    /// }
    /// ```
    @NotificationBuilder
    func applyNestedRules<NEW>(for keyPath: WritableKeyPath<Value, NEW>) -> [NotificationToken]
    where NEW: BehavioralStateContract {
        let state: UIBinding<NEW> = observe(keyPath)
        NEW.applyNotificationRules(to: state)
    }
}

/// Makes optional types conform to `BehavioralStateContract` when their wrapped type does.
///
/// This allows optional submodels to participate in binding and notification rules
/// as long as they are not `nil`.
///
/// This is useful in hierarchical or compositional state trees.
///
/// ### Example
/// ```swift
/// struct ParentState: BehavioralStateContract {
///     var child: ChildState?
///
///     static func applyBindingRules(to state: RulesPublisher) -> [AnyCancellable] {
///         state.applyNestedRules(to: \.child)
///     }
///
///     static func applyNotificationRules(to state: UIBinding<Self>) -> [NotificationToken] {
///         state.applyNestedRules(for: \.child)
///     }
/// }
/// ```
extension Optional: BehavioralStateContract where Wrapped: BehavioralStateContract {
    public func applyRules() {}

    @SubscriptionBuilder
    public static func applyBindingRules(to state: RulesPublisher) -> [AnyCancellable] {}

    @NotificationBuilder
    public static func applyNotificationRules(to state: UIBinding<Self>) -> [NotificationToken] {}

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
