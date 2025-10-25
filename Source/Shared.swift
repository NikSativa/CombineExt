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

/// Checks if a specific property differs between two values using a key path.
///
/// This function compares the values at the specified key path between two instances
/// and returns `true` if they differ, `false` if they are equal.
///
/// **Performance Note**: This function is marked with `@inline(__always)` for performance
/// and thread safety reasons, as it's designed to be called frequently in reactive
/// state management scenarios where race conditions could occur without inlining.
///
/// - Parameters:
///   - lhs: The first value to compare.
///   - rhs: The second value to compare.
///   - keyPath: A key path to the property to compare.
/// - Returns: `true` if the values at the key path differ, `false` otherwise.
///
/// ### Example
/// ```swift
/// struct Person {
///     let name: String
///     let age: Int
/// }
///
/// let person1 = Person(name: "Alice", age: 30)
/// let person2 = Person(name: "Bob", age: 25)
///
/// let nameDiffers = differs(lhs: person1, rhs: person2, keyPath: \.name)
/// let ageDiffers = differs(lhs: person1, rhs: person2, keyPath: \.age)
/// ```
@inline(__always)
public func differs<T>(lhs: T, rhs: T, keyPath: KeyPath<T, some Equatable>) -> Bool {
    return lhs[keyPath: keyPath] != rhs[keyPath: keyPath]
}
