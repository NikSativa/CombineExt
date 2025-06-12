import Foundation

/// A result builder that collects `NotificationToken` values using DSL-style syntax.
///
/// `AnyTokenBuilder` simplifies the creation of multiple `NotificationToken` instances and converts them into an array. It supports all standard result builder constructs including conditionals, optional blocks, and loops.
///
/// ### Example
/// ```swift
/// let tokens: [NotificationToken] = AnyTokenBuilder.build {
///     NotificationCenter.default.add(forName: .didUpdate) { _ in print("Update") }
///     if isEnabled {
///         NotificationCenter.default.add(forName: .didRefresh) { _ in print("Refresh") }
///     }
/// }
/// ```
@resultBuilder
public struct AnyTokenBuilder<Value> {
    /// Combines multiple arrays of values into a single flattened array.
    ///
    /// - Parameter components: Variadic arrays of values.
    /// - Returns: A flattened array.
    public static func buildBlock(_ components: [Value]...) -> [Value] {
        return components.flatMap { $0 }
    }

    /// Builds a block with an optional array of values.
    ///
    /// - Parameter component: An optional array of values.
    /// - Returns: The unwrapped array, or an empty array if `nil`.
    public static func buildOptional(_ component: [Value]?) -> [Value] {
        return component ?? []
    }

    /// Builds the `if` branch of a conditional statement.
    ///
    /// - Parameter component: The array returned by the `if` branch.
    /// - Returns: The same array.
    public static func buildEither(first component: [Value]) -> [Value] {
        return component
    }

    /// Builds the `else` branch of a conditional statement.
    ///
    /// - Parameter component: The array returned by the `else` branch.
    /// - Returns: The same array.
    public static func buildEither(second component: [Value]) -> [Value] {
        return component
    }

    /// Flattens an array of arrays into a single array.
    ///
    /// - Parameter components: An array of arrays.
    /// - Returns: A flattened array.
    public static func buildArray(_ components: [[Value]]) -> [Value] {
        return components.flatMap { $0 }
    }

    /// Builds a block for conditionally included values, such as `#available`.
    ///
    /// - Parameter component: The array from the available block.
    /// - Returns: The same array.
    public static func buildLimitedAvailability(_ component: [Value]) -> [Value] {
        return component
    }

    /// Converts a single value into an array containing that value.
    ///
    /// - Parameter expression: A single value.
    /// - Returns: A one-element array.
    public static func buildExpression(_ expression: Value) -> [Value] {
        return [expression]
    }

    /// Returns the provided array of values as-is.
    ///
    /// - Parameter expression: An array of values.
    /// - Returns: The same array.
    public static func buildExpression(_ expression: [Value]) -> [Value] {
        return expression
    }

    /// Allows void expressions in the builder without affecting the output.
    ///
    /// - Returns: An empty array.
    public static func buildExpression(_: Void) -> [Value] {
        return []
    }
}
