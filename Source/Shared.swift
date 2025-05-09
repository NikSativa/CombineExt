import Combine
import Foundation

/// Re-exported Combine types to allow usage in other modules without directly importing Combine.
/// A cancellable token that executes cleanup when deinitialized.
public typealias AnyCancellable = Combine.AnyCancellable

/// A Combine subject that publishes values of `Output` type without failure.
public typealias EventSubject<Output> = PassthroughSubject<Output, Never>

/// A Combine subject that publishes `Void` events without failure, useful for actions.
public typealias ActionSubject = PassthroughSubject<Void, Never>
