import CombineExt
import Foundation

struct TestModel: BehavioralStateContract, CustomDebugStringConvertible {
    var number: Int = 0
    var binding: Int = 0
    var text: String = "initial"

    @IgnoredState
    var voidClosure: () -> Void = {}

    @IgnoredState
    var getClosure: () -> Int = { 42 }

    @IgnoredState
    var setClosure: (Int) -> Void = { t in print(t) }

    @IgnoredState
    var getSetClosure: (Int) -> Int = { t in t + 1 }

    @IgnoredState
    var ignoredValue: Int = 0

    var debugDescription: String {
        return "<number: \(number), binding: \(binding), text: \(text)>"
    }

    mutating func applyRules() {
        text = "\(number)"

        voidClosure()
        setClosure(24)
        print(getClosure())
        print(getSetClosure(25))

        ignoredValue += 1
    }

    @SubscriptionBuilder
    static func applyBindingRules(to state: RulesPublisher) -> [AnyCancellable] {
        state.bindDiffed(to: \.number) { parent in
            parent.new.binding = parent.new.number
            parent.new.ignoredValue += 1
        }
    }

    @AnyTokenBuilder<Any>
    static func applyAnyRules(to state: UIBinding<Self>) -> [Any] {}
}

extension TestModel {
    init(number: Int, binding: Int) {
        self.number = number
        self.binding = binding
        self.text = "\(number)"
    }
}
