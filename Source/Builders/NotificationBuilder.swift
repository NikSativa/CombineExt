import Foundation

/// A result builder that collects `NotificationToken` instances using DSL-like syntax,
/// and converts them into an array of `NotificationToken` for use with Combine subscriptions.
@resultBuilder
public struct NotificationBuilder {
    /// Combines multiple arrays of `NotificationToken` into a single flat array of `NotificationToken`.
    ///
    /// - Parameter components: Variadic arrays of `NotificationToken` instances.
    /// - Returns: A flattened array of type-erased `NotificationToken` instances.
    public static func buildBlock(_ components: [NotificationToken]...) -> [NotificationToken] {
        return components.flatMap { $0 }
    }

    /// Handles optional blocks in the result builder.
    ///
    /// - Parameter component: An optional array of `NotificationToken`.
    /// - Returns: The unwrapped array converted to `NotificationToken`, or an empty array if nil.
    public static func buildOptional(_ component: [NotificationToken]?) -> [NotificationToken] {
        return component ?? []
    }

    /// Handles the first branch of an `if-else` conditional block.
    ///
    /// - Parameter component: The array of `NotificationToken` returned by the `if` branch.
    /// - Returns: An array of `NotificationToken`.
    public static func buildEither(first component: [NotificationToken]) -> [NotificationToken] {
        return component
    }

    /// Handles the second branch of an `if-else` conditional block.
    ///
    /// - Parameter component: The array of `NotificationToken` returned by the `else` branch.
    /// - Returns: An array of `NotificationToken`.
    public static func buildEither(second component: [NotificationToken]) -> [NotificationToken] {
        return component
    }

    /// Flattens an array of `[NotificationToken]` arrays, such as from a loop.
    ///
    /// - Parameter components: An array of arrays of `NotificationToken`.
    /// - Returns: A single flattened array of `NotificationToken`.
    public static func buildArray(_ components: [[NotificationToken]]) -> [NotificationToken] {
        return components.flatMap { $0 }
    }

    /// Handles conditionally included blocks, like those using `#available`.
    ///
    /// - Parameter component: An array of `NotificationToken` returned from a block conditionally compiled.
    /// - Returns: An array of `NotificationToken`.
    public static func buildLimitedAvailability(_ component: [NotificationToken]) -> [NotificationToken] {
        return component
    }

    /// Converts a single `NotificationToken` expression into an array of `NotificationToken`.
    ///
    /// - Parameter expression: A `NotificationToken` instance.
    /// - Returns: A one-element array containing the type-erased `NotificationToken`.
    public static func buildExpression(_ expression: NotificationToken) -> [NotificationToken] {
        return [expression]
    }

    /// Converts an array of `NotificationToken` instances into an array of `NotificationToken`.
    ///
    /// - Parameter expression: An array of `NotificationToken`.
    /// - Returns: The array with each element type-erased to `NotificationToken`.
    public static func buildExpression(_ expression: [NotificationToken]) -> [NotificationToken] {
        return expression
    }

    /// Supports void expressions (like `print()` or logging) in the result builder.
    ///
    /// - Returns: An empty array, allowing such expressions without affecting the output.
    public static func buildExpression(_: Void) -> [NotificationToken] {
        return []
    }
}
