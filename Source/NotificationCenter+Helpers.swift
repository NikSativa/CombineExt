import Foundation

public extension NotificationCenter {
    func post(name aName: NSNotification.Name) {
        post(name: aName, object: nil)
    }

    #if swift(>=6.0)
    /// Adds compatibility for Swift 6.0+ where `@Sendable` is required for closures capturing state across concurrency domains.
    /// Falls back to standard closure for earlier Swift versions.
    func add(forName name: NSNotification.Name,
             object obj: Any? = nil,
             queue: OperationQueue? = nil,
             using block: @Sendable @escaping (Notification) -> Void) -> NotificationToken {
        let token = addObserver(forName: name, object: obj, queue: queue, using: block)
        return .init(token: token)
    }
    #else
    /// Adds compatibility for Swift 6.0+ where `@Sendable` is required for closures capturing state across concurrency domains.
    /// Falls back to standard closure for earlier Swift versions.
    func add(forName name: NSNotification.Name,
             object obj: Any? = nil,
             queue: OperationQueue? = nil,
             using block: @escaping (Notification) -> Void) -> NotificationToken {
        let token = addObserver(forName: name, object: obj, queue: queue, using: block)
        return .init(token: token)
    }
    #endif
}

/// A lightweight wrapper around an `NSObjectProtocol` used for NotificationCenter observation.
/// Automatically unregisters the observer on deinitialization, preventing memory leaks or redundant notifications.
public final class NotificationToken {
    private let token: NSObjectProtocol

    init(token: NSObjectProtocol) {
        self.token = token
    }

    /// Assigns the token to a reference-writable key path on a given object. Useful for automatic token storage in a property.
    /// - Returns: The same token for chaining.
    @discardableResult
    public func assign<Root>(to keyPath: ReferenceWritableKeyPath<Root, Any?>, on object: Root) -> NotificationToken {
        object[keyPath: keyPath] = self
        return self
    }

    /// Assigns the token to an optional `NotificationToken` reference key path. Useful for storing and replacing tokens.
    /// - Returns: The same token for chaining.
    @discardableResult
    public func assign<Root>(to keyPath: ReferenceWritableKeyPath<Root, NotificationToken?>, on object: Root) -> NotificationToken {
        object[keyPath: keyPath] = self
        return self
    }

    /// Stores the token in a mutable collection (e.g. array) for lifecycle retention.
    /// - Parameter collection: The collection to store this token in.
    public func store<C: RangeReplaceableCollection>(in collection: inout C) where C.Element == NotificationToken {
        collection.append(self)
    }

    /// Automatically removes the observer when the token is deallocated.
    deinit {
        NotificationCenter.default.removeObserver(token)
    }
}
