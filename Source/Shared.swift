import Combine
import Foundation

/// open to other framework without importing of Combine
public typealias AnyCancellable = Combine.AnyCancellable

public typealias EventSubject<Output> = PassthroughSubject<Output, Never>
public typealias ActionSubject = PassthroughSubject<Void, Never>
