import Foundation
import Bedrock

public struct PersistentMap<Key: DataEncodable, Value> {
    typealias Internal = InternalNode<Value>
    typealias Leaf = Internal.LeafType
    typealias Node = Internal.Node
    private let root: Node?
    
    public var count: Int {
        guard let root = root else {
            return 0
        }
        switch root {
        case .internalNode(let box):
            return box.value.count()
        case .leafNode:
            return 1
        }
    }
    
    public init() {
        self.init(root: nil)
    }
    
    public init(elements: [(Key, Value)]) {
        self = elements.reduce(Self()) { result, entry in
            return result.setting(key: entry.0, to: entry.1)
        }
    }
    
    public func getFirstElement() -> (Key, Value)? {
        guard let root = root else { return nil }
        var stack = Stack<(Leaf.PathSegment, Node)>()
        stack.push((Leaf.PathSegment(), root))
        while (!stack.isEmpty) {
            let curr = stack.pop()
            let node = curr!.1
            let path = curr!.0
            switch node {
            case .internalNode(let box):
                if box.value.getValue() != nil {
                    let data = Data(path + box.value.getPathSegment())
                    let key = Key(data: data)!
                    return (key, box.value.getValue()!)
                }
                let nodeTuples = box.value.getChildren().map { (path + box.value.getPathSegment(), $0) }
                stack.push(nodeTuples.first!)
            case .leafNode(let leafType):
                let data = Data(path + leafType.pathSegment)
                let key = Key(data: data)!
                return (key, leafType.value)
            }
        }
        return nil
    }
    
    public func getElements() -> [(Key, Value)] {
        guard let root = root else { return [] }
        var stack = Stack<(Leaf.PathSegment, Node)>()
        var elements = [(Key, Value)]()
        stack.push((Leaf.PathSegment(), root))
        while (!stack.isEmpty) {
            let curr = stack.pop()
            let node = curr!.1
            let path = curr!.0
            switch node {
            case .internalNode(let box):
                if box.value.getValue() != nil {
                    let data = Data(path + box.value.getPathSegment())
                    let key = Key(data: data)!
                    elements.append((key, box.value.getValue()!))
                }
                let nodeTuples = box.value.getChildren().map { (path + box.value.getPathSegment(), $0) }
                stack.pushAll(nodeTuples)
            case .leafNode(let leafType):
                let data = Data(path + leafType.pathSegment)
                let key = Key(data: data)!
                elements.append((key, leafType.value))
            }
        }
        return elements
    }
    
    public func countGreaterOrEqual(to target: Int) -> Bool {
        if target == 0 { return true }
        guard let root = root else { return false }
        var stack = Stack<(Leaf.PathSegment, Node)>()
        var currentCount = 0
        stack.push((Leaf.PathSegment(), root))
        while (!stack.isEmpty) {
            let curr = stack.pop()
            let node = curr!.1
            let path = curr!.0
            switch node {
            case .internalNode(let box):
                if box.value.getValue() != nil {
                    currentCount += 1
                }
                let nodeTuples = box.value.getChildren().map { (path + box.value.getPathSegment(), $0) }
                stack.pushAll(nodeTuples)
                if stack.count + currentCount >= target { return true }
            case .leafNode:
                currentCount += 1
            }
        }
        return currentCount >= target
    }
    
    public func isEmpty() -> Bool {
        return root == nil
    }
    
    init(root: Node?) {
        self.root = root
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
                let newMap = Self(root: Node.internalNode(Box<Internal>(result)))
                return newMap
            case .leafNode(let leafType):
                let result = Internal.combining(key: keyData, keyIndex: 0, value: value, combine: combine, replace: true, leaf: leafType)
                switch result {
                case .internalNode:
                    return Self(root: result)
                case .leafNode:
                    return Self(root: result)
                }
            }
        }
        else {
            let newLeaf = InternalNode.LeafType(pathSegment: keyData, value: value)
            return Self(root: Node.leafNode(newLeaf))
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
        return merge(other: other, combine: { return $1 })
    }
    
    public func merge(other: Self, combine: (Value, Value) -> Value) -> Self {
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
                let newMerged = box.value.merging(other: otherBox.value, overwrite: combine)
                return Self(root: Node.internalNode(Box(newMerged)))
            case .leafNode(let otherLeafType):
                let result = box.value.combining(key: otherLeafType.pathSegment, keyIndex: 0, value: otherLeafType.value, combine: combine, replace: true)
                return Self(root: Node.internalNode(Box(result)))
            }
        case .leafNode(let leafType):
            switch otherRoot {
            case .internalNode(let box):
                let result = box.value.combining(key: leafType.pathSegment, keyIndex: 0, value: leafType.value, combine: combine, replace: false)
                return Self(root: Node.internalNode(Box(result)))
            case .leafNode(let otherLeafType):
                let result = InternalNode.combining(leftLeaf: leafType, rightLeaf: otherLeafType, combine: combine)
                switch result {
                case .internalNode:
                    return Self(root: result)
                case .leafNode:
                    return Self(root: result)
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
                    return Self(root: newNode)
                case .leafNode(let leafType):
                    let newLeaf = Node.leafNode(leafType)
                    return Self(root: newLeaf)
                }
            }
            return self
        case .leafNode(let leafType):
            if let childResult = leafType.deleting(key: keyData, keyIndex: 0) {
                return Self(root: Node.leafNode(childResult))
            }
            return Self(root: nil)
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
    
    public struct DynamicCodingKeys: CodingKey {
        public var stringValue: String
        
        public init?(stringValue: String) {
            self.stringValue = stringValue
        }
        
        public var intValue: Int?
        
        public init?(intValue: Int) {
            return nil
        }
    }
    
    public init(from decoder: Decoder) throws {
        var elements = [(Key, Value)]()
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
        for key in container.allKeys {
            guard let decodedKey = Key(key.stringValue) else {
                throw DecodingError.dataCorruptedError(forKey: key, in: container, debugDescription: "Invalid Key: \(key.stringValue)")
            }
            guard let codingKey = DynamicCodingKeys(stringValue: key.stringValue), let decodedValue = try? container.decode(Value.self, forKey: codingKey) else {
                throw DecodingError.dataCorruptedError(forKey: key, in: container, debugDescription: "Invalid Value for Key: \(key.stringValue)")
            }
            elements.append((decodedKey, decodedValue))
        }
        self.init(elements: elements)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicCodingKeys.self)
        let elements = self.getElements()
        for element in elements {
            try container.encode(element.1, forKey: DynamicCodingKeys(stringValue: element.0.description)!)
        }
    }
}
