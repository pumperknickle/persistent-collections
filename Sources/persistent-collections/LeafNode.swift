import Foundation

struct LeafNode<V> {
    typealias PathSegment = ArraySlice<UInt8>
    let pathSegment: PathSegment
    let value: V
    
    func get(key: PathSegment, keyIndex: Int) -> V? {
        if key.compare(idx: keyIndex, other: pathSegment, otherIdx: 0, countSimilar: 0) == -1 {
            return value
        }
        else {
            return nil
        }
    }
    
    func deleting(key: PathSegment, keyIndex: Int) -> Self? {
        if key.compare(idx: keyIndex, other: pathSegment, otherIdx: 0, countSimilar: 0) == -1 {
            return nil
        }
        else {
            return self
        }
    }
}

extension LeafNode: Equatable where V: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.pathSegment == rhs.pathSegment && lhs.value == rhs.value
    }
}
