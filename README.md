# CombineExt

Swift library that provides additional features for Combine framework.

### ValueSubject
Reference type that wraps a value and allows to publish changes to it.

```swift
struct State: Equatable {
    var counter: Int
    var toggle: Bool
}

@ValueSubject
var subject: State = .init(counter: 0, toggle: false)

@ValueSubject
var newCounterSubject: Int
_newCounterSubject = _subject.observe(keyPath: \.counter)

var newCounterStates: [Int] = []
$newCounterSubject.sink { state in
    newCounterStates.append(state)
}.store(in: &observers)

newCounterSubject += 1 // will trigger subject update
```
