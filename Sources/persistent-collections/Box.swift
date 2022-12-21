import Foundation

final class Ref<T> {
  var val : T
  init(_ v : T) {val = v}
}

public struct Box<T> {
    var ref : Ref<T>
    public init(_ x : T) { ref = Ref(x) }

    public var value: T {
        get { return ref.val }
        set {
          if (!isKnownUniquelyReferenced(&ref)) {
            ref = Ref(newValue)
            return
          }
          ref.val = newValue
        }
    }
}

extension Box: Equatable where T: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.value == rhs.value
    }
}
