import Combine
import Foundation

@dynamicMemberLookup
@propertyWrapper
public struct UIBinding<Output>: Combine.Publisher {
    public typealias Failure = Never

    private let publisher: AnyPublisher<Output, Failure>?
    private let get: () -> Output
    private let set: (Output) -> Void

    public var wrappedValue: Output {
        get { get() }
        nonmutating set {
            set(newValue)
        }
    }

    public var projectedValue: UIBinding<Output> {
        return self
    }

    /// don't use it directly!
    /// only for UIKit workaround
    ///
    /// @Binding
    /// var some: Int
    ///
    public init() {
        self.get = { fatalError("init(): must supply initial value") }
        self.set = { _ in }
        self.publisher = nil
    }

    public init(publisher: AnyPublisher<Output, Failure>? = nil,
                get: @escaping () -> Output,
                set: @escaping (Output) -> Void) {
        self.get = get
        self.set = set
        self.publisher = publisher
    }

    public func receive<S>(subscriber: S)
    where S: Subscriber, Failure == S.Failure, Output == S.Input {
        publisher?.receive(subscriber: subscriber)
    }

    public func observe<New>(_ keyPath: WritableKeyPath<Output, New>) -> UIBinding<New> {
        let newPublisher = publisher?.map(keyPath).eraseToAnyPublisher()

        return .init(publisher: newPublisher) {
            return self.wrappedValue[keyPath: keyPath]
        } set: { [self] new in
            wrappedValue[keyPath: keyPath] = new
        }
    }
}

public extension UIBinding {
    subscript<V>(dynamicMember keyPath: WritableKeyPath<Output, V>) -> UIBinding<V> {
        return observe(keyPath)
    }

    subscript<V>(dynamicMember keyPath: WritableKeyPath<Output, V>) -> V {
        get {
            wrappedValue[keyPath: keyPath]
        }
        set {
            wrappedValue[keyPath: keyPath] = newValue
        }
    }
}
