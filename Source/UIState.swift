import Combine
import Foundation

@dynamicMemberLookup
@propertyWrapper
public final class UIState<Output: Equatable>: Combine.Publisher {
    public typealias Failure = Never

    private lazy var subject: CurrentValueSubject<Output, Failure> = CurrentValueSubject(wrappedValue)
    private var observers: Set<AnyCancellable> = []

    private var underlyingValue: Output
    public var wrappedValue: Output {
        get {
            return underlyingValue
        }
        set {
            if underlyingValue == newValue {
                return
            }

            underlyingValue = newValue
            subject.send(newValue)
        }
    }

    public required init(wrappedValue: Output) {
        self.underlyingValue = wrappedValue
    }

    public var projectedValue: UIState<Output> {
        return self
    }

    public lazy var publisher: AnyPublisher<Output, Failure> = {
        return subject
            .removeDuplicates()
            .eraseToAnyPublisher()
    }()

    public func receive<S>(subscriber: S)
    where S: Subscriber, Failure == S.Failure, Output == S.Input {
        subject.receive(subscriber: subscriber)
    }

    public func observe<New>(_ keyPath: WritableKeyPath<Output, New>) -> UIBinding<New> {
        return .init(publisher: publisher.map(keyPath).eraseToAnyPublisher()) {
            return self.wrappedValue[keyPath: keyPath]
        } set: { [self] new in
            self.wrappedValue[keyPath: keyPath] = new
        }
    }
}

public extension UIState where Output: ExpressibleByNilLiteral {
    convenience init() {
        self.init(wrappedValue: nil)
    }
}

public extension UIState where Output: ExpressibleByArrayLiteral {
    convenience init() {
        self.init(wrappedValue: [])
    }
}

public extension UIState where Output: ExpressibleByDictionaryLiteral {
    convenience init() {
        self.init(wrappedValue: [:])
    }
}

public extension UIState {
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
