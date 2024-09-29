import Combine
import Foundation

@propertyWrapper
public final class ValueSubject<Output>: Combine.Publisher {
    public typealias Failure = Never

    private let subject: any Subject<Output, Failure>
    private var observers: Set<AnyCancellable> = []
    private var isIgnoringNewValues: Bool = true

    private var underlyingValue: Output
    public var wrappedValue: Output {
        get {
            return underlyingValue
        }
        set {
            underlyingValue = newValue

            guard isIgnoringNewValues else {
                return
            }
            subject.send(newValue)
        }
    }

    public required init(wrappedValue: Output) {
        self.subject = CurrentValueSubject(wrappedValue)
        self.underlyingValue = wrappedValue
    }

    public lazy var projectedValue: AnyPublisher<Output, Failure> = {
        return subject.eraseToAnyPublisher()
    }()

    public func receive<S>(subscriber: S)
    where S: Subscriber, Failure == S.Failure, Output == S.Input {
        subject.receive(subscriber: subscriber)
    }

    public func observe<New>(keyPath: WritableKeyPath<Output, New>) -> ValueSubject<New> {
        let newValue = wrappedValue[keyPath: keyPath]
        let new = ValueSubject<New>(wrappedValue: newValue)

        map(keyPath)
            .dropFirst()
            .sink { [unowned new, weak self] value in
                self?.isIgnoringNewValues = false
                new.wrappedValue = value
                self?.isIgnoringNewValues = true
            }.store(in: &new.observers)

        new.dropFirst()
            .sink { [unowned self, weak new] value in
                new?.isIgnoringNewValues = false
                wrappedValue[keyPath: keyPath] = value
                new?.isIgnoringNewValues = true
            }.store(in: &observers)

        return new
    }
}

public extension ValueSubject where Output: ExpressibleByNilLiteral {
    convenience init() {
        self.init(wrappedValue: nil)
    }
}

public extension ValueSubject where Output: ExpressibleByArrayLiteral {
    convenience init() {
        self.init(wrappedValue: [])
    }
}

public extension ValueSubject where Output: ExpressibleByDictionaryLiteral {
    convenience init() {
        self.init(wrappedValue: [:])
    }
}

public extension Publisher {
    func filterNils<NewOutput>() -> Publishers.CompactMap<Self, NewOutput>
    where Output == NewOutput? {
        return compactMap {
            return $0
        }
    }

    func mapVoid() -> Publishers.Map<Self, Void> {
        return map { _ in () }
    }
}
