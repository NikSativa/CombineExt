import Combine
import Foundation

// MARK: - CombineLatest Publishers

public extension Combine.Publishers {
    /// A publisher that receives and combines the latest elements from four publishers.
    struct CombineLatest5<A, B, C, D, E>: Publisher
    where A: Publisher, B: Publisher, C: Publisher, D: Publisher, E: Publisher, A.Failure == B.Failure, B.Failure == C.Failure, C.Failure == D.Failure, D.Failure == E.Failure {
        /// The kind of values published by this publisher.
        ///
        /// This publisher produces five-element tuples of the upstream publishers' output types.
        public typealias Output = (A.Output, B.Output, C.Output, D.Output, E.Output)

        /// The kind of errors this publisher might publish.
        ///
        /// This publisher produces the failure type shared by its upstream publishers.
        public typealias Failure = A.Failure

        public let a: A
        public let b: B
        public let c: C
        public let d: D
        public let e: E

        private typealias Zipped = Publishers.CombineLatest<Publishers.CombineLatest3<A, B, C>, Publishers.CombineLatest<D, E>>
        private let real: Publishers.Map<Zipped, Output>

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
        /// Implementations of ``Publisher`` must implement this method.
        ///
        /// The provided implementation of ``Publisher/subscribe(_:)-4u8kn``calls this method.
        ///
        /// - Parameter subscriber: The subscriber to attach to this ``Publisher``, after which it can receive values.
        public func receive<S>(subscriber: S) where S: Subscriber, D.Failure == S.Failure, S.Input == Output {
            real.receive(subscriber: subscriber)
        }
    }

    /// A publisher that receives and combines the latest elements from four publishers.
    struct CombineLatest6<A, B, C, D, E, F>: Publisher
    where A: Publisher, B: Publisher, C: Publisher, D: Publisher, E: Publisher, F: Publisher, A.Failure == B.Failure, B.Failure == C.Failure, C.Failure == D.Failure, D.Failure == E.Failure, E.Failure == F.Failure {
        /// The kind of values published by this publisher.
        ///
        /// This publisher produces five-element tuples of the upstream publishers' output types.
        public typealias Output = (A.Output, B.Output, C.Output, D.Output, E.Output, F.Output)

        /// The kind of errors this publisher might publish.
        ///
        /// This publisher produces the failure type shared by its upstream publishers.
        public typealias Failure = A.Failure

        public let a: A
        public let b: B
        public let c: C
        public let d: D
        public let e: E
        public let f: F

        private typealias Zipped = Publishers.CombineLatest<Publishers.CombineLatest3<A, B, C>, Publishers.CombineLatest3<D, E, F>>
        private let real: Publishers.Map<Zipped, Output>

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
        /// Implementations of ``Publisher`` must implement this method.
        ///
        /// The provided implementation of ``Publisher/subscribe(_:)-4u8kn``calls this method.
        ///
        /// - Parameter subscriber: The subscriber to attach to this ``Publisher``, after which it can receive values.
        public func receive<S>(subscriber: S) where S: Subscriber, D.Failure == S.Failure, S.Input == Output {
            real.receive(subscriber: subscriber)
        }
    }
}

// MARK: - zip Publishers

public extension Combine.Publishers {
    /// A publisher created by applying the zip function to five upstream publishers.
    ///
    /// Use a `Publishers.Zip5` to combine the latest elements from five publishers and emit a tuple to the downstream. The returned publisher waits until all five publishers have emitted an event, then delivers the oldest unconsumed event from each publisher as a tuple to the subscriber.
    ///
    /// If any upstream publisher finishes successfully or fails with an error, so too does the zipped publisher.
    struct Zip5<A, B, C, D, E>: Publisher
    where A: Publisher, B: Publisher, C: Publisher, D: Publisher, E: Publisher, A.Failure == B.Failure, B.Failure == C.Failure, C.Failure == D.Failure, D.Failure == E.Failure {
        /// The kind of values published by this publisher.
        ///
        /// This publisher produces five-element tuples, whose members' types correspond to the types produced by the upstream publishers.
        public typealias Output = (A.Output, B.Output, C.Output, D.Output, E.Output)

        /// The kind of errors this publisher might publish.
        ///
        /// This publisher uses its upstream publishers' common failure type.
        public typealias Failure = A.Failure

        /// A publisher to zip.
        public let a: A

        /// A second publisher to zip.
        public let b: B

        /// A third publisher to zip.
        public let c: C

        /// A fourth publisher to zip.
        public let d: D

        /// A fifth publisher to zip.
        public let e: E

        private typealias Zipped = Publishers.Zip<Publishers.Zip3<A, B, C>, Publishers.Zip<D, E>>
        private let real: Publishers.Map<Zipped, Output>

        /// Creates a publisher created by applying the zip function to five upstream publishers.
        /// - Parameters:
        ///   - a: A publisher to zip.
        ///   - b: A second publisher to zip.
        ///   - c: A third publisher to zip.
        ///   - d: A fourth publisher to zip.
        ///   - e: A fifth publisher to zip.
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
        /// Implementations of ``Publisher`` must implement this method.
        ///
        /// The provided implementation of ``Publisher/subscribe(_:)-4u8kn``calls this method.
        ///
        /// - Parameter subscriber: The subscriber to attach to this ``Publisher``, after which it can receive values.
        public func receive<S>(subscriber: S) where S: Subscriber, E.Failure == S.Failure, S.Input == Output {
            real.receive(subscriber: subscriber)
        }
    }

    /// A publisher created by applying the zip function to six upstream publishers.
    ///
    /// Use a `Publishers.Zip6` to combine the latest elements from six publishers and emit a tuple to the downstream. The returned publisher waits until all six publishers have emitted an event, then delivers the oldest unconsumed event from each publisher as a tuple to the subscriber.
    ///
    /// If any upstream publisher finishes successfully or fails with an error, so too does the zipped publisher.
    struct Zip6<A, B, C, D, E, F>: Publisher
    where A: Publisher, B: Publisher, C: Publisher, D: Publisher, E: Publisher, F: Publisher, A.Failure == B.Failure, B.Failure == C.Failure, C.Failure == D.Failure, D.Failure == E.Failure, E.Failure == F.Failure {
        /// The kind of values published by this publisher.
        ///
        /// This publisher produces six-element tuples, whose members' types correspond to the types produced by the upstream publishers.
        public typealias Output = (A.Output, B.Output, C.Output, D.Output, E.Output, F.Output)

        /// The kind of errors this publisher might publish.
        ///
        /// This publisher uses its upstream publishers' common failure type.
        public typealias Failure = A.Failure

        /// A publisher to zip.
        public let a: A

        /// A second publisher to zip.
        public let b: B

        /// A third publisher to zip.
        public let c: C

        /// A fourth publisher to zip.
        public let d: D

        /// A fifth publisher to zip.
        public let e: E

        /// A sixth publisher to zip.
        public let f: F

        private typealias Zipped = Publishers.Zip<Publishers.Zip3<A, B, C>, Publishers.Zip3<D, E, F>>
        private let real: Publishers.Map<Zipped, Output>

        /// Creates a publisher created by applying the zip function to six upstream publishers.
        /// - Parameters:
        ///   - a: A publisher to zip.
        ///   - b: A second publisher to zip.
        ///   - c: A third publisher to zip.
        ///   - d: A fourth publisher to zip.
        ///   - e: A fifth publisher to zip.
        ///   - f: A sixth publisher to zip.
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
        /// Implementations of ``Publisher`` must implement this method.
        ///
        /// The provided implementation of ``Publisher/subscribe(_:)-4u8kn``calls this method.
        ///
        /// - Parameter subscriber: The subscriber to attach to this ``Publisher``, after which it can receive values.
        public func receive<S>(subscriber: S) where S: Subscriber, E.Failure == S.Failure, S.Input == Output {
            real.receive(subscriber: subscriber)
        }
    }
}
