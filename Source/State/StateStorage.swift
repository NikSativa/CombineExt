import Foundation
import Observation

final class StateStorage<Value: Equatable> {
    let lock: NSLocking
    var lockedValue: Value
    /// The type is `Any?` because a stored property cannot have a type that is not available on every supported platform.
    private let observationRegistrar: Any?
    private var observedFields: [AnyKeyPath: ObservedField<Value>] = [:]

    init(value: Value, lock: StateLock?) {
        self.lockedValue = value
        self.lock = (lock ?? StateDefaultLock).makeLock()

        if #available(iOS 17, macOS 14, tvOS 17, watchOS 10, visionOS 1, *) {
            self.observationRegistrar = ObservationRegistrar()
        } else {
            self.observationRegistrar = nil
        }
    }

    func read() -> Value {
        if #available(iOS 17, macOS 14, tvOS 17, watchOS 10, visionOS 1, *),
           let registrar = observationRegistrar as? ObservationRegistrar {
            registrar.access(self, keyPath: \.lockedValue)
        }

        return lock.withLock {
            return lockedValue
        }
    }

    func read<Field>(_ keyPath: KeyPath<Value, Field>) -> Field {
        guard #available(iOS 17, macOS 14, tvOS 17, watchOS 10, visionOS 1, *),
              let registrar = observationRegistrar as? ObservationRegistrar else {
            return lock.withLock {
                return lockedValue[keyPath: keyPath]
            }
        }

        let (value, field) = lock.withLock {
            return (lockedValue[keyPath: keyPath], observedField(at: keyPath, registrar: registrar))
        }

        if let field {
            field.registerAccess(self)
        } else {
            registrar.access(self, keyPath: \.lockedValue)
        }
        return value
    }

    func replaceLockedValue(with newValue: Value) {
        guard #available(iOS 17, macOS 14, tvOS 17, watchOS 10, visionOS 1, *),
              let registrar = observationRegistrar as? ObservationRegistrar else {
            lockedValue = newValue
            return
        }

        let changedFields = observedFields.values.filter { field in
            return field.hasChanged(lockedValue, newValue)
        }

        registrar.withMutation(of: self, keyPath: \.lockedValue) {
            for field in changedFields {
                field.willSet(self)
            }
            lockedValue = newValue
            for field in changedFields {
                field.didSet(self)
            }
        }
    }

    @available(iOS 17, macOS 14, tvOS 17, watchOS 10, visionOS 1, *)
    private func observedField<Field>(at keyPath: KeyPath<Value, Field>, registrar: ObservationRegistrar) -> ObservedField<Value>? {
        if let field = observedFields[keyPath] {
            return field
        }

        guard let equatableType = Field.self as? any Equatable.Type,
              let field = ObservedField(keyPath, comparedAs: equatableType, registrar: registrar) else {
            return nil
        }

        observedFields[keyPath] = field
        return field
    }
}

@available(iOS 17, macOS 14, tvOS 17, watchOS 10, visionOS 1, *)
extension StateStorage: Observation.Observable {}

private struct ObservedField<Root: Equatable> {
    let hasChanged: (_ old: Root, _ new: Root) -> Bool
    let registerAccess: (_ storage: StateStorage<Root>) -> Void
    let willSet: (_ storage: StateStorage<Root>) -> Void
    let didSet: (_ storage: StateStorage<Root>) -> Void

    @available(iOS 17, macOS 14, tvOS 17, watchOS 10, visionOS 1, *)
    init?<Field, EquatableField: Equatable>(_ keyPath: KeyPath<Root, Field>,
                                            comparedAs _: EquatableField.Type,
                                            registrar: ObservationRegistrar) {
        guard let keyPath = keyPath as? KeyPath<Root, EquatableField> else {
            return nil
        }

        let observationKeyPath = (\StateStorage<Root>.lockedValue).appending(path: keyPath)
        self.hasChanged = { old, new in
            return old[keyPath: keyPath] != new[keyPath: keyPath]
        }
        self.registerAccess = { storage in
            registrar.access(storage, keyPath: observationKeyPath)
        }
        self.willSet = { storage in
            registrar.willSet(storage, keyPath: observationKeyPath)
        }
        self.didSet = { storage in
            registrar.didSet(storage, keyPath: observationKeyPath)
        }
    }
}
