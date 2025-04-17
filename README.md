# CombineExt
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FNikSativa%2FCombineExt%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/NikSativa/CombineExt)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FNikSativa%2FCombineExt%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/NikSativa/CombineExt)

Swift library that provides additional features for Combine framework.

### UIState + UIBinding
Reference type that wraps a value and allows to publish changes to it.

```swift
struct State: Equatable {
    var counter: Int
    var toggle: Bool
}

@UIState
var subject: State = .init(counter: 0, toggle: false)

@UIBinding
var newCounterSubject: Int
_newCounterSubject = _subject.observe(keyPath: \.counter)

var newCounterStates: [Int] = []
$newCounterSubject.sink { state in
    newCounterStates.append(state)
}.store(in: &observers)

newCounterSubject += 1 // will trigger subject update
```

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
