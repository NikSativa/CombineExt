import CombineExt
import Foundation

struct TestModel: BehavioralStateContract, CustomDebugStringConvertible {
    var number: Int = 0
    var binding: Int = 0
    var text: String = "initial"

    var debugDescription: String {
        return "<number: \(number), binding: \(binding), text: \(text)>"
    }

    mutating func applyRules() {
        text = "\(number)"
    }

    @SubscriptionBuilder
    static func applyBindingRules(to state: RulesPublisher) -> [AnyCancellable] {
        state.bindDiffed(to: \.number) { parent in
            parent.new.binding = parent.new.number
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
