import Combine
import Foundation

/// A property wrapper and coordinator class that manages the reactive state and actions of a model conforming to `BehavioralStateContract`.
///
/// It applies custom binding and notification rules, routes actions, and ensures updates trigger `postActionsProcessing()` consistently.
/// Intended to enable a SwiftUI-like reactive model architecture in UIKit.
@dynamicMemberLookup
@propertyWrapper
public final class ManagedState<Value: BehavioralStateContract> {
    public typealias Action = Value.Action?
    public typealias ActionStreamConfigurator = (AnyPublisher<Action, Never>) -> AnyPublisher<[Action], Never>

    /// The current model value being managed by this coordinator.
    @UIState
    public var wrappedValue: Value
    /// Returns the coordinator itself, enabling use of `$model` to access helper methods and bindings.
    public var projectedValue: ManagedState<Value> {
        return self
    }

    private var isEnabled: Bool = true
    private var selfBindingRules: [AnyCancellable] = []
    private var bindingRules: [AnyCancellable] = []
    private var substates: [AnyCancellable] = []
    private var notificationRules: [NotificationToken] = []
    private let actionStream: PassthroughSubject<Action, Never> = .init()
    private var firstRunActions: [Action]? = []

    public init(wrappedValue: Value) where Value: AnyObject {
        assertionFailure("ManagedState does not support reference types")
        fatalError("ManagedState does not support reference types")
    }

    /// Initializes the coordinator with a value-type model. This will configure bindings, notifications, and apply initial actions.
    /// - Parameter wrappedValue: The initial value of the model.
    public init(wrappedValue: Value, actionStreamConfigurator: ActionStreamConfigurator? = nil) {
        assert(Mirror(reflecting: wrappedValue).displayStyle != .class, "ManagedState does not support reference types")

        self.wrappedValue = wrappedValue

        self.isEnabled = false
        selfBindingRules += subscribe(actionStreamConfigurator)
        bindingRules += applyBindingRules()
        notificationRules += applyNotificationRules()
        self.isEnabled = true

        receive(firstRunActions ?? [])
        self.firstRunActions = nil
    }

    /// Applies model-defined notification rules using the `@NotificationBuilder`.
    @NotificationBuilder
    private func applyNotificationRules() -> [NotificationToken] {
        Value.applyNotificationRules(to: self)
    }

    /// Applies model-defined binding rules using the `@SubscriptionBuilder`.
    /// Also emits a `.rootChanged` action when the root state changes.
    @SubscriptionBuilder
    private func applyBindingRules() -> [AnyCancellable] {
        let state = $wrappedValue.observe(\.self)
        state
            .removeDuplicates()
            .sink { [weak actionStream] _ in
                actionStream?.send(nil)
            }

        let nestedReceiver = makeNestedReceiver()
        Value.applyBindingRules(for: state, to: nestedReceiver)
    }

    /// Subscribes to the internal action stream and forwards actions to the model via `receive`.
    @SubscriptionBuilder
    private func subscribe(_ actionStreamConfigurator: ActionStreamConfigurator?) -> [AnyCancellable] {
        let commonStream = actionStream
            .filter { [unowned self] _ in
                return isEnabled
            }
            .eraseToAnyPublisher()

        let actionStream: AnyPublisher<[Action], Never>
        if let actionStreamConfigurator {
            actionStream = actionStreamConfigurator(commonStream)
        } else {
            actionStream = commonStream
                .collect(.byTime(DispatchQueue.main, .microseconds(10)))
                .eraseToAnyPublisher()
        }

        actionStream
            .sink { [unowned self] action in
                receive(action)
            }
    }

    /// Creates an action receiver that will trigger model updates and cache actions during initial setup.
    private func makeNestedReceiver() -> EventSubject<Value.Action> {
        let newReceiver: EventSubject<Value.Action> = .init()
        newReceiver.sink { [weak self] new in
            self?.actionStream.send(new)
            self?.firstRunActions?.append(new)
        }.store(in: &selfBindingRules)
        return newReceiver
    }

    /// Applies a list of actions to the model, updates its state, and triggers `postActionsProcessing`.
    private func receive(_ actions: [Action]) {
        isEnabled = false

        var wrappedValue = self.wrappedValue
        for action in actions {
            switch action {
            case .some(let action):
                wrappedValue.apply(action)
            case .none:
                break
            }
        }
        wrappedValue.postActionsProcessing()
        self.wrappedValue = wrappedValue

        isEnabled = true
    }
}

public extension ManagedState {
    /// Sends an action to the coordinator, triggering any associated binding rules or state updates.
    ///
    /// This method allows manual emission of an `Action` that conforms to the `BehavioralStateContract`.
    /// It is typically used to initiate a state change or side-effect from external sources.
    ///
    /// - Parameter action: The action to dispatch to the underlying model.
    func send(_ action: Value.Action) {
        actionStream.send(action)
    }
}

public extension ManagedState {
    /// Creates a reactive binding to a specific key path in the model.
    func observe<S>(_ keyPath: WritableKeyPath<Value, S>) -> UIBinding<S> {
        return $wrappedValue.observe(keyPath)
    }

    /// Enables shorthand access for reactive bindings using dynamic member lookup syntax (e.g., `$model.property`).
    subscript<S>(dynamicMember keyPath: WritableKeyPath<Value, S>) -> UIBinding<S> {
        return observe(keyPath)
    }

    /// Enables direct get/set access to the model's properties using dynamic member lookup (e.g., `model.property`).
    subscript<S>(dynamicMember keyPath: WritableKeyPath<Value, S>) -> S {
        get {
            wrappedValue[keyPath: keyPath]
        }
        set {
            wrappedValue[keyPath: keyPath] = newValue
        }
    }
}

public extension ManagedState {
    /// Creates a `UIState` binding to a nested value inside the model, allowing isolated observation and mutation.
    func state<New>(_ keyPath: WritableKeyPath<Value, New>) -> UIState<New> {
        let state: UIState<New> = .init(wrappedValue: wrappedValue[keyPath: keyPath])
        state
            .removeDuplicates()
            .sink { [weak self] new in
                self?.wrappedValue[keyPath: keyPath] = new
            }
            .store(in: &substates)
        return state
    }

    /// Creates a nested `ManagedState` for a nested model value, allowing recursive coordination.
    func coordinator<New>(_ keyPath: WritableKeyPath<Value, New>) -> ManagedState<New> {
        let state: ManagedState<New> = .init(wrappedValue: wrappedValue[keyPath: keyPath])
        state
            .observe(\.self)
            .removeDuplicates()
            .sink { [weak self] new in
                self?.wrappedValue[keyPath: keyPath] = new
            }
            .store(in: &substates)
        return state
    }
}

#if swift(>=6.0)
extension ManagedState: @unchecked Sendable {}
#endif
