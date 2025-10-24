import Combine
import Foundation

/// A result builder that collects `Cancellable` instances using DSL-like syntax,
/// and converts them into an array of `AnyCancellable` for use with Combine subscriptions.
@resultBuilder
public struct SubscriptionBuilder {
    /// Creates an array of `AnyCancellable` instances using the subscription builder DSL.
    ///
    /// This method provides a convenient way to collect multiple cancellable subscriptions
    /// using the result builder syntax and convert them into an array for storage.
    ///
    /// - Parameter content: A closure that uses the subscription builder DSL to create cancellables.
    /// - Returns: An array of type-erased `AnyCancellable` instances.
    ///
    /// ### Example
    /// ```swift
    /// let cancellables = SubscriptionBuilder.subscribe {
    ///     publisher1.sink { print($0) }
    ///     publisher2.sink { print($0) }
    ///     if condition {
    ///         publisher3.sink { print($0) }
    ///     }
    /// }
    /// ```
    public static func subscribe(@SubscriptionBuilder content: () -> [AnyCancellable]) -> [AnyCancellable] {
        return content()
    }

    /// Combines multiple arrays of `Cancellable` into a single flat array of `AnyCancellable`.
    ///
    /// - Parameter components: Variadic arrays of `Cancellable` instances.
    /// - Returns: A flattened array of type-erased `AnyCancellable` instances.
    public static func buildBlock(_ components: [Cancellable]...) -> [AnyCancellable] {
        return components.flatMap { $0.map(\.eraseToAnyCancellable) }
    }

    /// Handles optional blocks in the result builder.
    ///
    /// - Parameter component: An optional array of `Cancellable`.
    /// - Returns: The unwrapped array converted to `AnyCancellable`, or an empty array if nil.
    public static func buildOptional(_ component: [Cancellable]?) -> [AnyCancellable] {
        return component?.map(\.eraseToAnyCancellable) ?? []
    }

    /// Handles the first branch of an `if-else` conditional block.
    ///
    /// - Parameter component: The array of `Cancellable` returned by the `if` branch.
    /// - Returns: An array of `AnyCancellable`.
    public static func buildEither(first component: [Cancellable]) -> [AnyCancellable] {
        return component.map(\.eraseToAnyCancellable)
    }

    /// Handles the second branch of an `if-else` conditional block.
    ///
    /// - Parameter component: The array of `Cancellable` returned by the `else` branch.
    /// - Returns: An array of `AnyCancellable`.
    public static func buildEither(second component: [Cancellable]) -> [AnyCancellable] {
        return component.map(\.eraseToAnyCancellable)
    }

    /// Flattens an array of `[Cancellable]` arrays, such as from a loop.
    ///
    /// - Parameter components: An array of arrays of `Cancellable`.
    /// - Returns: A single flattened array of `AnyCancellable`.
    public static func buildArray(_ components: [[Cancellable]]) -> [AnyCancellable] {
        return components.flatMap { $0.map(\.eraseToAnyCancellable) }
    }

    /// Handles conditionally included blocks, like those using `#available`.
    ///
    /// - Parameter component: An array of `Cancellable` returned from a block conditionally compiled.
    /// - Returns: An array of `AnyCancellable`.
    public static func buildLimitedAvailability(_ component: [Cancellable]) -> [AnyCancellable] {
        return component.map(\.eraseToAnyCancellable)
    }

    /// Converts a single `Cancellable` expression into an array of `AnyCancellable`.
    ///
    /// - Parameter expression: A `Cancellable` instance.
    /// - Returns: A one-element array containing the type-erased `Cancellable`.
    public static func buildExpression(_ expression: Cancellable) -> [AnyCancellable] {
        return [expression.eraseToAnyCancellable]
    }

    /// Converts an array of `Cancellable` instances into an array of `AnyCancellable`.
    ///
    /// - Parameter expression: An array of `Cancellable`.
    /// - Returns: The array with each element type-erased to `AnyCancellable`.
    public static func buildExpression(_ expression: [Cancellable]) -> [AnyCancellable] {
        return expression.map(\.eraseToAnyCancellable)
    }

    /// Supports void expressions (like `print()` or logging) in the result builder.
    ///
    /// - Returns: An empty array, allowing such expressions without affecting the output.
    public static func buildExpression(_: Void) -> [AnyCancellable] {
        return []
    }
}

private extension Cancellable {
    /// Convenience for erasing any `Cancellable` to `AnyCancellable`.
    var eraseToAnyCancellable: AnyCancellable {
        (self as? AnyCancellable) ?? AnyCancellable(self)
    }
}
