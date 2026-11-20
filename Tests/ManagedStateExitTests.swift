#if compiler(>=6.2) && os(macOS) && DEBUG
import Combine
import CombineExt
import Testing

@Suite(.timeLimit(.minutes(1)))
struct ManagedStateExitTests {
    @Test
    func rulesThatDoNotConvergeStopADebugBuild() async {
        let result = await #expect(processExitsWith: .failure, observing: [\.standardErrorContent]) {
            _ = ManagedState(wrappedValue: EndlessRulesModel())
        }

        let errorOutput = String(decoding: result?.standardErrorContent ?? [], as: UTF8.self)
        #expect(errorOutput.contains("Cyclic dependency detected in state rules"))
    }
}

private struct EndlessRulesModel: BehavioralStateContract {
    var passes: Int = 0

    mutating func applyRules() {
        passes += 1
    }

    @SubscriptionBuilder
    static func applyBindingRules(to state: RulesPublisher) -> [AnyCancellable] {}

    @AnyTokenBuilder<Any>
    static func applyAnyRules(to state: UIBinding<Self>) -> [Any] {}
}
#endif
