import Foundation

/// A protocol for state types that handle actions and support optional post-processing
/// after actions are applied. Commonly used in MVVM architectures to define how models
/// respond to intents from the ViewModel.
public protocol ActionHandlingState {
    /// The type representing all possible actions that can be applied to the state.
    associatedtype Action

    /// Applies the given action to mutate the state.
    ///
    /// - Parameter action: The action to be applied.
    mutating func apply(_ action: Action)

    /// Called after one or more actions have been applied.
    /// Use this to update derived properties or perform any post-mutation logic.
    mutating func postActionsProcessing()
}
