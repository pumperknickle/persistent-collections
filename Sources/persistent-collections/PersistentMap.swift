import Foundation
import Bedrock

public struct PersistentMap<Key: DataEncodable, Value> {
    typealias Internal = InternalNode<Value>
    typealias Leaf = Internal.LeafType
    typealias Node = Internal.Node
    private let root: Node?
    public let count: Int
    
    public init() {
        self.init(root: nil, count: 0)
    }
    
    public init(dictionaryLiteral elements: [(Key, Value)]) {
        self = elements.reduce(Self()) { result, entry in
            return result.setting(key: entry.0, to: entry.1)
        }
    }
    
//    public func getElements() -> [(Key, Value)] {
//
//    }
    
    init(root: Node?, count: Int) {
        self.root = root
        self.count = count
    }
    
    public func setting(key: Key, to value: Value) -> Self {
        return combining(key: key, to: value) { lhs, rhs in
            return rhs
        }
    }
    
    public func combining(key: Key, to value: Value, combine: (Value, Value) -> Value) -> Self {
        let keyData = key.toData()
        if let root = root {
            switch root {
            case .internalNode(let internalNode):
                let result = internalNode.value.combining(key: key.toData(), keyIndex: 0, value: value, combine: combine, replace: true)
                let newMap = Self(root: Node.internalNode(Box<Internal>(result.0)), count: result.1 ? count + 1 : count)
                return newMap
            case .leafNode(let leafType):
                let result = Internal.combining(key: keyData, keyIndex: 0, value: value, combine: combine, replace: true, leaf: leafType)
                switch result {
                case .internalNode:
                    return Self(root: result, count: 2)
                case .leafNode:
                    return Self(root: result, count: 1)
                }
            }
        }
        else {
            let newLeaf = InternalNode.LeafType(pathSegment: keyData, value: value)
            return Self(root: Node.leafNode(newLeaf), count: 1)
        }
    }
    
    public func get(key: Key) -> Value? {
        guard let root = root else { return nil }
        let keyData = key.toData()
        switch root {
        case .internalNode(let internalNode):
            return internalNode.value.get(key:keyData, keyIndex: 0)
        case .leafNode(let leafType):
            return leafType.get(key: keyData, keyIndex: 0)
        }
    }
    
    public func contains(key: Key) -> Bool {
        return get(key: key) != nil
    }
    
    public func overwrite(with other: Self) -> Self {
        return merge(other: other, overwrite: { return $1 })
    }
    
    public func merge(other: Self, overwrite: (Value, Value) -> Value) -> Self {
        guard let root = root else {
            return other
        }
        guard let otherRoot = other.root else {
            return self
        }
        switch root {
        case .internalNode(let box):
            switch otherRoot {
            case .internalNode(let otherBox):
                let newMerged = box.value.merging(other: otherBox.value, overwrite: overwrite)
                return Self(root: Node.internalNode(Box(newMerged)), count: newMerged.getCount())
            case .leafNode(let otherLeafType):
                let result = box.value.combining(key: otherLeafType.pathSegment, keyIndex: 0, value: otherLeafType.value, combine: overwrite, replace: true)
                return Self(root: Node.internalNode(Box(result.0)), count: result.1 ? count + 1 : count)
            }
        case .leafNode(let leafType):
            switch otherRoot {
            case .internalNode(let box):
                let result = box.value.combining(key: leafType.pathSegment, keyIndex: 0, value: leafType.value, combine: overwrite, replace: false)
                return Self(root: Node.internalNode(Box(result.0)), count: result.1 ? count + 1 : count)
            case .leafNode(let otherLeafType):
                let result = InternalNode.combining(leftLeaf: leafType, rightLeaf: otherLeafType, combine: overwrite)
                switch result {
                case .internalNode:
                    return Self(root: result, count: 2)
                case .leafNode:
                    return Self(root: result, count: 1)
                }
            }
        }
    }
    
    public func deleting(key: Key) -> Self {
        guard let root = root else { return self }
        let keyData = key.toData()
        switch root {
        case .internalNode(let box):
            if let childResult = box.value.deleting(key: keyData, keyIndex: 0) {
                switch childResult {
                case .internalNode(let newBox):
                    let newNode = Node.internalNode(newBox)
                    return Self(root: newNode, count: count - 1)
                case .leafNode(let leafType):
                    let newLeaf = Node.leafNode(leafType)
                    return Self(root: newLeaf, count: 1)
                }
            }
            return self
        case .leafNode(let leafType):
            if let childResult = leafType.deleting(key: keyData, keyIndex: 0) {
                return Self(root: Node.leafNode(childResult), count: 1)
            }
            return Self(root: nil, count: 0)
        }
    }
}

extension PersistentMap: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (Key, Value)...) {
        self = elements.reduce(Self()) { result, entry in
            return result.setting(key: entry.0, to: entry.1)
        }
    }
}

extension PersistentMap: Equatable where Value: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        if lhs.root == nil && rhs.root == nil { return true }
        if lhs.count != rhs.count { return false }
        if let lroot = lhs.root, let rroot = lhs.root {
            switch lroot {
            case .internalNode(let lbox):
                switch rroot {
                case .internalNode(let rbox):
                    return lbox == rbox
                case .leafNode:
                    return false
                }
            case .leafNode(let lleaf):
                switch rroot {
                case .internalNode:
                    return false
                case .leafNode(let rleaf):
                    return lleaf == rleaf
                }
            }
        }
        return false
    }
}

extension PersistentMap: Codable where Key: LosslessStringConvertible, Value: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let stringDictionary = try container.decode([String: Value].self)
        var elements = [(Key, Value)]()
        for (stringKey, value) in stringDictionary {
            guard let key = Key(stringKey) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid key '\(stringKey)'")
            }
            elements.append((key, value))
        }
        self.init(dictionaryLiteral: elements)
    }
    
    public func encode(to encoder: Encoder) throws {
        
    }
}
