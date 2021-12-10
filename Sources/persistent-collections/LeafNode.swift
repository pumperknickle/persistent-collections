import Foundation

struct LeafNode<V> {
    typealias PathSegment = Data
    let pathSegment: PathSegment
    let value: V
    let count: Int
    
    func get(key: PathSegment, keyIndex: Int) -> V? {
        if key.compare(idx: keyIndex, other: pathSegment, otherIdx: 0, countSimilar: 0) == -1 {
            return value
        }
        else {
            return nil
        }
    }
    
    func deleting(key: PathSegment, keyIndex: Int, deletion: (V) -> (V, Bool)?) -> (Self, Bool)? {
        if key.compare(idx: keyIndex, other: pathSegment, otherIdx: 0, countSimilar: 0) == -1 {
            guard let newValue = deletion(value) else { return nil }
            if newValue.1 { return (Self(pathSegment: pathSegment, value: newValue.0, count: count - 1), true) }
        }
        return (self, false)
    }
}

extension LeafNode: Equatable where V: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.pathSegment == rhs.pathSegment && lhs.value == rhs.value
    }
}
