import Combine
import Foundation

/// A type-erased `Cancellable` token that automatically cancels its underlying operation when deallocated.
///
/// Use `AnyCancellable` to store references to Combine subscriptions and manage their lifecycle,
/// especially in contexts like view models or closures.
///
/// ### Example
/// ```swift
/// var cancellables = Set<AnyCancellable>()
///
/// publisher
///     .sink { value in
///         print("Received:", value)
///     }
///     .store(in: &cancellables)
/// ```
public typealias AnyCancellable = Combine.AnyCancellable

/// A Combine subject that emits values of a specified type and never fails.
///
/// Use `EventSubject` to create a simple event pipeline that emits values of a specific type,
/// such as user input, navigation events, or simple state changes.
///
/// ### Example
/// ```swift
/// let messageSubject: EventSubject<String> = .init()
///
/// messageSubject
///     .sink { print("Received:", $0) }
///     .store(in: &cancellables)
///
/// messageSubject.send("Hello")
/// ```
public typealias EventSubject<Output> = PassthroughSubject<Output, Never>

/// A Combine subject that emits `Void` values without failure, typically used to model UI actions or event triggers.
///
/// `ActionSubject` is a convenient alias for `PassthroughSubject<Void, Never>`. Use it for fire-and-forget style signals,
/// such as button taps or user interactions.
///
/// ### Example
/// ```swift
/// let didTapButton = ActionSubject()
///
/// didTapButton
///     .sink { print("Button was tapped!") }
///     .store(in: &cancellables)
///
/// didTapButton.send(())
/// ```
public typealias ActionSubject = PassthroughSubject<Void, Never>
