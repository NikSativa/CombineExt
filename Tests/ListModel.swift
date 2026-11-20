import CombineExt
import Foundation

struct ListModel: BehavioralStateContract {
    var counter: Int = 0
    var list: [Int] = []

    mutating func applyRules() {}

    @SubscriptionBuilder
    static func applyBindingRules(to state: RulesPublisher) -> [AnyCancellable] {}

    @AnyTokenBuilder<Any>
    static func applyAnyRules(to state: UIBinding<Self>) -> [Any] {}
}
