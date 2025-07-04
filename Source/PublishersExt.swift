import Combine
import Foundation

public extension Publisher {
    /// Filters out `nil` values from a stream of optional elements.
    ///
    /// This method unwraps optional values, allowing downstream subscribers to receive only non-`nil` values.
    ///
    /// - Returns: A publisher emitting only the non-`nil` elements of the upstream optional stream.
    ///
    /// ### Example
    /// ```swift
    /// Just<String?>(nil)
    ///     .filterNils()
    ///     .sink { print($0) } // This will not be called
    ///
    /// Just("Hello")
    ///     .filterNils()
    ///     .sink { print($0) } // Prints "Hello"
    /// ```
    func filterNils<NewOutput>() -> Publishers.CompactMap<Self, NewOutput>
    where Output == NewOutput? {
        return compactMap {
            return $0
        }
    }

    /// Maps all emitted elements to `Void`, ignoring their values.
    ///
    /// This is useful when only the fact that an event occurred is needed, not its data.
    ///
    /// - Returns: A publisher that emits `Void` for every event from the upstream publisher.
    ///
    /// ### Example
    /// ```swift
    /// Just(42)
    ///     .mapVoid()
    ///     .sink { print("Triggered") } // Prints "Triggered"
    /// ```
    func mapVoid() -> Publishers.Map<Self, Void> {
        return map { _ in () }
    }
}

public extension Combine.Publishers {
    /// A custom Combine publisher that combines the latest values from five upstream publishers.
    ///
    /// Emits a tuple of the latest values whenever any one of the upstream publishers emits a new element.
    /// The publisher starts emitting only after all publishers have emitted at least one value.
    /// It completes as soon as any of the upstream publishers completes.
    ///
    /// ### Example
    /// ```swift
    /// let a = PassthroughSubject<Int, Never>()
    /// let b = PassthroughSubject<String, Never>()
    /// let c = PassthroughSubject<Double, Never>()
    /// let d = PassthroughSubject<Bool, Never>()
    /// let e = PassthroughSubject<Character, Never>()
    ///
    /// let combined = Publishers.CombineLatest5(a, b, c, d, e)
    ///     .sink { print("Combined:", $0) }
    /// ```
    struct CombineLatest5<A, B, C, D, E>: Publisher
    where A: Publisher, B: Publisher, C: Publisher, D: Publisher, E: Publisher, A.Failure == B.Failure, B.Failure == C.Failure, C.Failure == D.Failure, D.Failure == E.Failure {
        /// The output type of the combined publisher — a tuple of all upstream outputs.
        public typealias Output = (A.Output, B.Output, C.Output, D.Output, E.Output)

        /// The shared failure type across all upstream publishers.
        public typealias Failure = A.Failure

        /// The first upstream publisher.
        public let a: A

        /// The second upstream publisher.
        public let b: B

        /// The third upstream publisher.
        public let c: C

        /// The fourth upstream publisher.
        public let d: D

        /// The fifth upstream publisher.
        public let e: E

        private typealias Zipped = Publishers.CombineLatest<Publishers.CombineLatest3<A, B, C>, Publishers.CombineLatest<D, E>>
        private let real: Publishers.Map<Zipped, Output>

        /// Initializes a `CombineLatest5` publisher.
        ///
        /// - Parameters:
        ///   - a: The first upstream publisher.
        ///   - b: The second upstream publisher.
        ///   - c: The third upstream publisher.
        ///   - d: The fourth upstream publisher.
        ///   - e: The fifth upstream publisher.
        public init(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E) {
            self.a = a
            self.b = b
            self.c = c
            self.d = d
            self.e = e

            self.real = Publishers.CombineLatest(Publishers.CombineLatest3(a, b, c), Publishers.CombineLatest(d, e)).map { a, b in
                return (a.0, a.1, a.2, b.0, b.1)
            }
        }

        /// Attaches the specified subscriber to this publisher.
        ///
        /// This function forwards the subscription to the underlying combined publisher.
        ///
        /// - Parameter subscriber: The subscriber to attach to this publisher.
        public func receive<S>(subscriber: S) where S: Subscriber, D.Failure == S.Failure, S.Input == Output {
            real.receive(subscriber: subscriber)
        }
    }

    /// A custom Combine publisher that combines the latest values from six upstream publishers.
    ///
    /// Emits a tuple of the latest values whenever any one of the upstream publishers emits a new element.
    /// The publisher starts emitting only after all publishers have emitted at least one value.
    /// It completes as soon as any of the upstream publishers completes.
    ///
    /// ### Example
    /// ```swift
    /// let a = PassthroughSubject<Int, Never>()
    /// let b = PassthroughSubject<String, Never>()
    /// let c = PassthroughSubject<Double, Never>()
    /// let d = PassthroughSubject<Bool, Never>()
    /// let e = PassthroughSubject<Character, Never>()
    /// let f = PassthroughSubject<Float, Never>()
    ///
    /// let combined = Publishers.CombineLatest6(a, b, c, d, e, f)
    ///     .sink { print("Combined:", $0) }
    /// ```
    struct CombineLatest6<A, B, C, D, E, F>: Publisher
    where A: Publisher, B: Publisher, C: Publisher, D: Publisher, E: Publisher, F: Publisher, A.Failure == B.Failure, B.Failure == C.Failure, C.Failure == D.Failure, D.Failure == E.Failure, E.Failure == F.Failure {
        /// The output type of the combined publisher — a tuple of all upstream outputs.
        public typealias Output = (A.Output, B.Output, C.Output, D.Output, E.Output, F.Output)

        /// The shared failure type across all upstream publishers.
        public typealias Failure = A.Failure

        /// The first upstream publisher.
        public let a: A

        /// The second upstream publisher.
        public let b: B

        /// The third upstream publisher.
        public let c: C

        /// The fourth upstream publisher.
        public let d: D

        /// The fifth upstream publisher.
        public let e: E

        /// The sixth upstream publisher.
        public let f: F

        private typealias Zipped = Publishers.CombineLatest<Publishers.CombineLatest3<A, B, C>, Publishers.CombineLatest3<D, E, F>>
        private let real: Publishers.Map<Zipped, Output>

        /// Initializes a `CombineLatest6` publisher.
        ///
        /// - Parameters:
        ///   - a: The first upstream publisher.
        ///   - b: The second upstream publisher.
        ///   - c: The third upstream publisher.
        ///   - d: The fourth upstream publisher.
        ///   - e: The fifth upstream publisher.
        ///   - f: The sixth upstream publisher.
        public init(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F) {
            self.a = a
            self.b = b
            self.c = c
            self.d = d
            self.e = e
            self.f = f

            self.real = Publishers.CombineLatest(Publishers.CombineLatest3(a, b, c), Publishers.CombineLatest3(d, e, f)).map { a, b in
                return (a.0, a.1, a.2, b.0, b.1, b.2)
            }
        }

        /// Attaches the specified subscriber to this publisher.
        ///
        /// This function forwards the subscription to the underlying combined publisher.
        ///
        /// - Parameter subscriber: The subscriber to attach to this publisher.
        public func receive<S>(subscriber: S) where S: Subscriber, D.Failure == S.Failure, S.Input == Output {
            real.receive(subscriber: subscriber)
        }
    }
}

public extension Combine.Publishers {
    /// A custom Combine publisher that zips together the outputs of five upstream publishers.
    ///
    /// Waits for all five publishers to emit values, then combines them into a tuple and emits it.
    /// Each subsequent output includes the next available value from each publisher, in order.
    /// The zipped publisher completes when the first upstream publisher completes.
    ///
    /// ### Example
    /// ```swift
    /// let a = PassthroughSubject<Int, Never>()
    /// let b = PassthroughSubject<String, Never>()
    /// let c = PassthroughSubject<Double, Never>()
    /// let d = PassthroughSubject<Bool, Never>()
    /// let e = PassthroughSubject<Character, Never>()
    ///
    /// let zipped = Publishers.Zip5(a, b, c, d, e)
    ///     .sink { print("Zipped:", $0) }
    /// ```
    struct Zip5<A, B, C, D, E>: Publisher
    where A: Publisher, B: Publisher, C: Publisher, D: Publisher, E: Publisher, A.Failure == B.Failure, B.Failure == C.Failure, C.Failure == D.Failure, D.Failure == E.Failure {
        /// The output type of the zipped publisher — a tuple of all upstream outputs.
        public typealias Output = (A.Output, B.Output, C.Output, D.Output, E.Output)

        /// The shared failure type across all upstream publishers.
        public typealias Failure = A.Failure

        /// The first upstream publisher.
        public let a: A

        /// The second upstream publisher.
        public let b: B

        /// The third upstream publisher.
        public let c: C

        /// The fourth upstream publisher.
        public let d: D

        /// The fifth upstream publisher.
        public let e: E

        private typealias Zipped = Publishers.Zip<Publishers.Zip3<A, B, C>, Publishers.Zip<D, E>>
        private let real: Publishers.Map<Zipped, Output>

        /// Initializes a `Zip5` publisher.
        ///
        /// - Parameters:
        ///   - a: The first upstream publisher.
        ///   - b: The second upstream publisher.
        ///   - c: The third upstream publisher.
        ///   - d: The fourth upstream publisher.
        ///   - e: The fifth upstream publisher.
        public init(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E) {
            self.a = a
            self.b = b
            self.c = c
            self.d = d
            self.e = e

            self.real = Publishers.Zip(Publishers.Zip3(a, b, c), Publishers.Zip(d, e)).map { a, b in
                return (a.0, a.1, a.2, b.0, b.1)
            }
        }

        /// Attaches the specified subscriber to this publisher.
        ///
        /// This function forwards the subscription to the underlying zipped publisher.
        ///
        /// - Parameter subscriber: The subscriber to attach to this publisher.
        public func receive<S>(subscriber: S) where S: Subscriber, E.Failure == S.Failure, S.Input == Output {
            real.receive(subscriber: subscriber)
        }
    }

    /// A custom Combine publisher that zips together the outputs of six upstream publishers.
    ///
    /// Waits for all six publishers to emit values, then combines them into a tuple and emits it.
    /// Each subsequent output includes the next available value from each publisher, in order.
    /// The zipped publisher completes when the first upstream publisher completes.
    ///
    /// ### Example
    /// ```swift
    /// let a = PassthroughSubject<Int, Never>()
    /// let b = PassthroughSubject<String, Never>()
    /// let c = PassthroughSubject<Double, Never>()
    /// let d = PassthroughSubject<Bool, Never>()
    /// let e = PassthroughSubject<Character, Never>()
    /// let f = PassthroughSubject<Float, Never>()
    ///
    /// let zipped = Publishers.Zip6(a, b, c, d, e, f)
    ///     .sink { print("Zipped:", $0) }
    /// ```
    struct Zip6<A, B, C, D, E, F>: Publisher
    where A: Publisher, B: Publisher, C: Publisher, D: Publisher, E: Publisher, F: Publisher, A.Failure == B.Failure, B.Failure == C.Failure, C.Failure == D.Failure, D.Failure == E.Failure, E.Failure == F.Failure {
        /// The output type of the zipped publisher — a tuple of all upstream outputs.
        public typealias Output = (A.Output, B.Output, C.Output, D.Output, E.Output, F.Output)

        /// The shared failure type across all upstream publishers.
        public typealias Failure = A.Failure

        /// The first upstream publisher.
        public let a: A

        /// The second upstream publisher.
        public let b: B

        /// The third upstream publisher.
        public let c: C

        /// The fourth upstream publisher.
        public let d: D

        /// The fifth upstream publisher.
        public let e: E

        /// The sixth upstream publisher.
        public let f: F

        private typealias Zipped = Publishers.Zip<Publishers.Zip3<A, B, C>, Publishers.Zip3<D, E, F>>
        private let real: Publishers.Map<Zipped, Output>

        /// Initializes a `Zip6` publisher.
        ///
        /// - Parameters:
        ///   - a: The first upstream publisher.
        ///   - b: The second upstream publisher.
        ///   - c: The third upstream publisher.
        ///   - d: The fourth upstream publisher.
        ///   - e: The fifth upstream publisher.
        ///   - f: The sixth upstream publisher.
        public init(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F) {
            self.a = a
            self.b = b
            self.c = c
            self.d = d
            self.e = e
            self.f = f

            self.real = Publishers.Zip(Publishers.Zip3(a, b, c), Publishers.Zip3(d, e, f)).map { a, b in
                return (a.0, a.1, a.2, b.0, b.1, b.2)
            }
        }

        /// Attaches the specified subscriber to this publisher.
        ///
        /// This function forwards the subscription to the underlying zipped publisher.
        ///
        /// - Parameter subscriber: The subscriber to attach to this publisher.
        public func receive<S>(subscriber: S) where S: Subscriber, E.Failure == S.Failure, S.Input == Output {
            real.receive(subscriber: subscriber)
        }
    }
}
