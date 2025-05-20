import Combine
import Foundation

public extension UIBinding where Output: ActionHandlingState {
    /// Binds a property change to an action using Combine.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the property being observed.
    ///   - action: The action to dispatch when the value at keyPath changes.
    ///   - receiver: The event subject that handles the dispatched action.
    /// - Returns: A cancellable Combine subscription.
    func bind<S: Equatable>(to keyPath: WritableKeyPath<Output, S>,
                            action: Output.Action,
                            receiver: EventSubject<Output.Action>) -> Cancellable {
        observe(keyPath)
            .removeDuplicates()
            .sink { [weak receiver] _ in
                receiver?.send(action)
            }
    }
}

public extension UIBinding where Output: BehavioralStateContract {
    /// Applies nested model binding rules and maps their actions to parent actions.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the nested model.
    ///   - receiver: The receiver that will handle mapped actions.
    ///   - mapping: A closure that transforms nested actions to parent model actions.
    /// - Returns: An array of cancellable Combine subscriptions.
    @SubscriptionBuilder
    func applyNestedRules<Value>(for keyPath: WritableKeyPath<Output, Value>,
                                 receiver: EventSubject<Output.Action>,
                                 mapping: @escaping (Value.Action) -> Output.Action) -> [AnyCancellable]
    where Value: BehavioralStateContract {
        let newReceiver: EventSubject<Value.Action> = .init()
        newReceiver.sink { new in
            receiver.send(mapping(new))
        }
        Value.applyBindingRules(for: observe(keyPath), to: newReceiver)
    }
}

public extension ManagedState {
    /// Applies notification rules to a nested model coordinator.
    ///
    /// - Parameter keyPath: The key path to the nested model.
    /// - Returns: An array of active notification tokens.
    @NotificationBuilder
    func applyNestedRules<New>(for keyPath: WritableKeyPath<Value, New>) -> [NotificationToken]
    where New: BehavioralStateContract {
        New.applyNotificationRules(to: coordinator(keyPath))
    }
}
