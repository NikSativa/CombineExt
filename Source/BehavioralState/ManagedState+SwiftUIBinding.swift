import SwiftUI

public extension ManagedState {
    /// Returns a SwiftUI binding to a property of the managed value.
    ///
    /// `$state.title` always returns a `Binding`, as the projected value of a SwiftUI `@State` does.
    /// Use the binding to give a property to a SwiftUI view that changes it, such as `TextField` or `Toggle`.
    /// A dynamic member of the binding returns a binding to a nested property, for example `$state.trip.title`.
    ///
    /// A read through the binding tracks only this property with the Observation framework, as `subscript(_:)` does.
    /// A write through the binding changes the managed value and runs the rules.
    ///
    /// To read the value of a property, use `subscript(_:)`, for example `$state[\.title]`.
    /// To get a `UIBinding`, use `ui`, for example `$state.ui.title`.
    ///
    /// - Parameter keyPath: A writable key path to a property of the managed value.
    /// - Returns: A SwiftUI binding to the property.
    ///
    /// ### Example
    /// ```swift
    /// TextField("Title", text: viewModel.$viewState.title)
    /// ```
    subscript<V>(dynamicMember keyPath: WritableKeyPath<Value, V>) -> Binding<V> {
        return Binding(threadSafeGet: {
            return self[keyPath]
        }, threadSafeSet: { newValue in
            self.wrappedValue[keyPath: keyPath] = newValue
        })
    }
}
