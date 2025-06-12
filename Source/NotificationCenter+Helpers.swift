import Foundation

public extension NotificationCenter {
    /// Posts a notification with the specified name using `nil` as the object.
    ///
    /// - Parameter aName: The name of the notification.
    ///
    /// ### Example
    /// ```swift
    /// NotificationCenter.default.post(name: .didUpdate)
    /// ```
    func post(name aName: NSNotification.Name) {
        post(name: aName, object: nil)
    }

    #if swift(>=6.0)
    /// Adds an observer for the specified notification name.
    ///
    /// Wraps `addObserver(forName:object:queue:using:)` and returns a `NotificationToken` that automatically unregisters on deallocation.
    ///
    /// - Parameters:
    ///   - name: The name of the notification to observe.
    ///   - obj: The object whose notifications the observer wants to receive; that is, only notifications sent by this sender are delivered to the observer.
    ///   - queue: The operation queue to which block should be added.
    ///   - block: The block to execute when the notification is received.
    /// - Returns: A `NotificationToken` that unregisters the observer when deallocated.
    ///
    /// ### Example
    /// ```swift
    /// let token = NotificationCenter.default.add(forName: .didUpdate) { notification in
    ///     print("Received:", notification)
    /// }
    /// ```
    func add(forName name: NSNotification.Name,
             object obj: Any? = nil,
             queue: OperationQueue? = nil,
             using block: @Sendable @escaping (Notification) -> Void) -> NotificationToken {
        let token = addObserver(forName: name, object: obj, queue: queue, using: block)
        return .init(token: token)
    }
    #else
    /// Adds an observer for the specified notification name.
    ///
    /// Wraps `addObserver(forName:object:queue:using:)` and returns a `NotificationToken` that automatically unregisters on deallocation.
    ///
    /// - Parameters:
    ///   - name: The name of the notification to observe.
    ///   - obj: The object whose notifications the observer wants to receive; that is, only notifications sent by this sender are delivered to the observer.
    ///   - queue: The operation queue to which block should be added.
    ///   - block: The block to execute when the notification is received.
    /// - Returns: A `NotificationToken` that unregisters the observer when deallocated.
    ///
    /// ### Example
    /// ```swift
    /// let token = NotificationCenter.default.add(forName: .didUpdate) { notification in
    ///     print("Received:", notification)
    /// }
    /// ```
    func add(forName name: NSNotification.Name,
             object obj: Any? = nil,
             queue: OperationQueue? = nil,
             using block: @escaping (Notification) -> Void) -> NotificationToken {
        let token = addObserver(forName: name, object: obj, queue: queue, using: block)
        return .init(token: token)
    }
    #endif
}

/// A lightweight wrapper around an `NSObjectProtocol` used for `NotificationCenter` observation.
///
/// `NotificationToken` ensures the observer is automatically removed when the token is deallocated,
/// preventing memory leaks and redundant notifications.
///
/// You can also store the token or assign it to a property using the helper methods.
public final class NotificationToken {
    private let token: NSObjectProtocol

    init(token: NSObjectProtocol) {
        self.token = token
    }

    /// Assigns this token to a reference-writable property of any type.
    ///
    /// Useful for storing the token in a generic property or when working with type-erased storage.
    ///
    /// - Parameters:
    ///   - keyPath: A key path to an `Any?` property on the target object.
    ///   - object: The object on which to assign the token.
    /// - Returns: The same token, allowing for call chaining.
    ///
    /// ### Example
    /// ```swift
    /// class Controller {
    ///     var anyStorage: Any?
    /// }
    ///
    /// token.assign(to: \.anyStorage, on: controller)
    /// ```
    @discardableResult
    public func assign<Root>(to keyPath: ReferenceWritableKeyPath<Root, Any?>, on object: Root) -> NotificationToken {
        object[keyPath: keyPath] = self
        return self
    }

    /// Assigns this token to a reference-writable `NotificationToken?` property.
    ///
    /// Useful when storing or replacing tokens directly on an object.
    ///
    /// - Parameters:
    ///   - keyPath: A key path to a `NotificationToken?` property.
    ///   - object: The object on which to assign the token.
    /// - Returns: The same token, allowing for call chaining.
    ///
    /// ### Example
    /// ```swift
    /// class Controller {
    ///     var token: NotificationToken?
    /// }
    ///
    /// token.assign(to: \.token, on: controller)
    /// ```
    @discardableResult
    public func assign<Root>(to keyPath: ReferenceWritableKeyPath<Root, NotificationToken?>, on object: Root) -> NotificationToken {
        object[keyPath: keyPath] = self
        return self
    }

    /// Stores the token in a mutable collection for retention.
    ///
    /// - Parameter collection: The collection to store the token in.
    ///
    /// ### Example
    /// ```swift
    /// var tokens = [NotificationToken]()
    /// token.store(in: &tokens)
    /// ```
    public func store<C: RangeReplaceableCollection>(in collection: inout C) where C.Element == NotificationToken {
        collection.append(self)
    }

    /// Automatically removes the observer when the token is deallocated.
    deinit {
        NotificationCenter.default.removeObserver(token)
    }
}
