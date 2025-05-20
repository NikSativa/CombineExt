import Foundation

/// A protocol that defines the reactive behavior contract for a model used with ManagedState.
public protocol BehavioralStateContract: Equatable, ActionHandlingState {
    /// Defines the Combine bindings between the model's state and the action receiver.
    /// Called automatically by `ManagedState` during initialization.
    ///
    /// - Parameters:
    ///   - state: A binding wrapper that allows observing and modifying the model.
    ///   - receiver: An event subject to which UI or system-driven actions can be sent.
    /// - Returns: An array of Combine `AnyCancellable` subscriptions.
    @SubscriptionBuilder
    static func applyBindingRules(for state: UIBinding<Self>, to receiver: EventSubject<Self.Action>) -> [AnyCancellable]

    /// Defines external notification-based rules that can affect the model's state.
    /// Common examples include app lifecycle events, system notifications, or external publishers.
    ///
    /// - Parameter coordinator: The `ManagedState` managing the model.
    /// - Returns: An array of `NotificationToken` objects to keep active.
    @NotificationBuilder
    static func applyNotificationRules(to coordinator: ManagedState<Self>) -> [NotificationToken]
}
