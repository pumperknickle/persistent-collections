import Foundation
import Bedrock

public struct ArrayTrie<Key: DataEncodable, Value> {
    typealias Node = ArrayTrieNode<Key, Value>
    typealias ChildMap = Node.ChildMap
    let children: PersistentMap<Key, Node>!
    
    init(children: ChildMap) {
        self.children = children
    }
    
    public var count: Int {
        return children.getElements().map { $0.1.count() }.reduce(0, +)
    }
    
    public init() {
        self = Self(children: ChildMap())
    }
    
    public func isEmpty() -> Bool {
        return children.isEmpty()
    }
    
    func changing(key: Key, node: Node?) -> Self {
        guard let node = node else { return Self( children: children.deleting(key: key)) }
        return Self(children: children.setting(key: key, to: node))
    }
    
    func getRoot(key: Key) -> Node? {
        return children.get(key: key)
    }
    
    public func get(keys: [Key]) -> Value? {
        guard let firstKey = keys.first else { return nil }
        guard let root = getRoot(key: firstKey) else { return nil }
        return root.get(keys: keys)
    }
    
    public func setting(keys: [Key], value: Value) -> Self {
        guard let firstKey = keys.first else { return self }
        guard let childNode = getRoot(key: firstKey) else {
            return changing(key: firstKey, node: Node(prefix: keys, value: value, children: Box(ChildMap())))
        }
        return changing(key: firstKey, node: childNode.setting(keys: keys, to: value))
    }
    
    public func contains(keys: [Key]) -> Bool {
        return get(keys: keys) != nil
    }
    
    public func deleting(keys: [Key]) -> Self {
        guard let firstKey = keys.first else { return self }
        guard let childNode = getRoot(key: firstKey) else { return self }
        return changing(key: firstKey, node: childNode.deleting(keys: keys))
    }
    
    // Keep only the nodes and values along "path"
    public func including(path: [Key]) -> Self {
        guard let firstKey = path.first else { return self }
        guard let childNode = children.get(key: firstKey) else { return Self(children: ChildMap()) }
        guard let childResult = childNode.including(keys: path) else { return Self(children: ChildMap()) }
        return Self(children: ChildMap().setting(key: firstKey, to: childResult))
    }
    
    // Keep every node and value except along "path"
    public func excluding(path: [Key]) -> Self {
        guard let firstKey = path.first else {
            return Self(children: ChildMap())
        }
        guard let childNode = children.get(key: firstKey) else { return self }
        return changing(key: firstKey, node: childNode.excluding(keys: path))
    }
    
    // Follow along path and take only the nodes and values that are descendents
    public func subtree(path: [Key]) -> Self {
        guard let firstKey = path.first else { return self }
        guard let childNode = children.get(key: firstKey), let childResult = childNode.subtree(keys: path) else { return Self(children: ChildMap()) }
        return Self(children: childResult)
    }
    
    // Add a prefix of path to each node
    public func supertree(path: [Key]) -> Self {
        guard let firstKey = path.first else { return self }
        guard let firstChild = children.getFirstElement() else { return self }
        if children.countGreaterOrEqual(to: 2) {
            return Self(children: ChildMap().setting(key: firstKey, to: Node(prefix: path, value: nil, children: Box(children))))
        }
        let childNode = firstChild.1.changing(prefix: path + firstChild.1.prefix)
        return Self(children: ChildMap().setting(key: firstKey, to: childNode))
    }
}
