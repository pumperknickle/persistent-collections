import Foundation
import Bedrock

struct ArrayTrieNode<Key: DataEncodable, Value> {
    typealias ChildMap = PersistentMap<Key, Self>
    let prefix: [Key]!
    let value: Value?
    let children: Box<ChildMap>!
    
    func count() -> Int {
        return children.value.getElements().map { $0.1.count() }.reduce(0, +) + (value != nil ? 1 : 0)
    }
    
    func getChild(_ key: Key) -> Self? {
        children.value.get(key: key)
    }
    
    func changing(prefix: [Key]) -> Self {
        Self(prefix: prefix, value: value, children: children)
    }
    
    func changing(value: Value?) -> Self {
        Self(prefix: prefix, value: value, children: children)
    }
    
    func changing(children: ChildMap) -> Self {
        Self(prefix: prefix, value: value, children: Box(children))
    }
    
    func changing(child: Key, node: Self?) -> Self {
        return node != nil ? changing(children: children.value.setting(key: child, to: node!)) : changing(children: children.value.deleting(key: child))
    }
    
    func get(keys: [Key]) -> Value? {
        if !keys.starts(with: prefix) { return nil }
        let suffix = keys - prefix
        guard let firstValue = suffix.first else { return value }
        guard let childNode = getChild(firstValue) else { return nil }
        return childNode.get(keys: suffix)
    }
    
    func setting(keys: [Key], to value: Value) -> Self {
        if keys.count >= prefix.count && keys.starts(with: prefix) {
            let suffix = keys - prefix
            guard let firstValue = suffix.first else { return changing(value: value) }
            guard let childNode = getChild(firstValue) else { return changing(child: firstValue, node: Self(prefix: suffix, value: value, children: Box(ChildMap())))}
            return changing(child: firstValue, node: childNode.setting(keys: suffix, to: value))
        }
        if prefix.count > keys.count && prefix.starts(with: keys) {
            let suffix = prefix - keys
            return Self(prefix: keys, value: value, children: Box(ChildMap().setting(key: suffix.first!, to: changing(prefix: suffix))))
        }
        let parentPrefix = keys ~> prefix
        let newPrefix = keys - parentPrefix
        let oldPrefix = prefix - parentPrefix
        let newNode = Self(prefix: newPrefix, value: value, children: Box(ChildMap()))
        let oldNode = changing(prefix: oldPrefix)
        return Self(prefix: parentPrefix, value: nil, children: Box(ChildMap().setting(key: newPrefix.first!, to: newNode).setting(key: oldPrefix.first!, to: oldNode)))
    }
    
    func deleting() -> Self? {
        if children.value.isEmpty() { return nil }
        if children.value.countGreaterOrEqual(to: 1) { return changing(value: nil) }
        let onlyChild = children.value.getElements().first!.1
        return onlyChild.changing(prefix: prefix + onlyChild.prefix)
    }
    
    func deleting(keys: [Key]) -> Self? {
        if !keys.starts(with: prefix) { return self }
        let suffix = keys - prefix
        guard let firstValue = suffix.first else { return deleting() }
        guard let child = getChild(firstValue) else { return self }
        guard let childResult = child.deleting(keys: suffix) else {
            if value != nil || children.value.countGreaterOrEqual(to: 3) { return changing(child: firstValue, node: nil) }
            let childNode = children.value.getElements().first(where: { $0.0 != firstValue })!
            return childNode.1.changing(prefix: prefix + childNode.1.prefix)
        }
        return changing(child: firstValue, node: childResult)
    }
    
    func including(keys: [Key]) -> Self? {
        if prefix.starts(with: keys) { return self }
        if !keys.starts(with: prefix) { return nil }
        let suffix = keys - prefix
        guard let firstSuffix = suffix.first else { return self }
        guard let child = children.value.get(key: firstSuffix) else { return nil }
        guard let childResult = child.including(keys: suffix) else { return nil }
        return changing(children: ChildMap().setting(key: firstSuffix, to: childResult))
    }
    
    func excluding(keys: [Key]) -> Self? {
        if prefix.starts(with: keys) { return nil }
        if !keys.starts(with: prefix) { return self }
        let suffix = keys - prefix
        guard let firstSuffix = suffix.first else { return nil }
        guard let child = children.value.get(key: firstSuffix) else { return self }
        guard let childResult = child.excluding(keys: suffix) else {
            if value != nil || children.value.countGreaterOrEqual(to: 3) { return changing(child: firstSuffix, node: nil) }
            let childNode = children.value.getElements().first(where: { $0.0 != firstSuffix })!
            return childNode.1.changing(prefix: prefix + childNode.1.prefix)
        }
        return changing(child: firstSuffix, node: childResult)
    }
    
    func subtree(keys: [Key]) -> PersistentMap<Key, Self>? {
        if prefix.starts(with: keys) {
            let suffix = prefix - keys
            guard let firstSuffix = suffix.first else { return children.value }
            return ChildMap().setting(key: firstSuffix, to: Self(prefix: suffix, value: value, children: children))
        }
        if !keys.starts(with: prefix) { return nil }
        let suffix = keys - prefix
        let firstSuffix = suffix.first!
        guard let child = children.value.get(key: firstSuffix) else { return nil }
        return child.subtree(keys: suffix)
    }
    
    func subtreeWithCover(keys: [Key], current: Value?) -> (ChildMap, Value?)? {
        let nextCurrent = value ?? current
        if prefix.starts(with: keys) {
            let suffix = prefix - keys
            guard let firstSuffix = suffix.first else { return (children.value, nextCurrent) }
            return (ChildMap().setting(key: firstSuffix, to: Self(prefix: suffix, value: value, children: children)), current)
        }
        if !keys.starts(with: prefix) { return nil }
        let suffix = keys - prefix
        let firstSuffix = suffix.first!
        guard let child = children.value.get(key: firstSuffix) else { return nil }
        return child.subtreeWithCover(keys: suffix, current: nextCurrent)
    }
    
    func merge(with node: Self, combine: (Value, Value) -> Value) -> Self {
        if node.prefix.starts(with: prefix) && prefix.count == node.prefix.count {
            let newValue = value != nil ? (node.value != nil ? combine(value!, node.value!) : value) : (node.value != nil ? node.value : nil)
            let newChildren = children.value.merge(other: node.children.value) { leftNode, rightNode in
                return leftNode.merge(with: rightNode, combine: combine)
            }
            return Self(prefix: prefix, value: newValue, children: Box(newChildren))
        }
        if prefix.starts(with: node.prefix) {
            let suffix = prefix - node.prefix
            let firstSuffix = suffix.first!
            guard let currentChild = node.children.value.get(key: firstSuffix) else {
                let newChildren = node.children.value.setting(key: firstSuffix, to: changing(prefix: suffix))
                return node.changing(children: newChildren)
            }
            let newChildren = node.children.value.setting(key: firstSuffix, to: changing(prefix: suffix).merge(with: currentChild, combine: combine))
            return node.changing(children: newChildren)
        }
        if node.prefix.starts(with: prefix) {
            let suffix = node.prefix - prefix
            let firstSuffix = suffix.first!
            guard let currentChild = children.value.get(key: firstSuffix) else {
                let newChildren = children.value.setting(key: firstSuffix, to: node.changing(prefix: suffix))
                return changing(children: newChildren)
            }
            let newChildren = children.value.setting(key: firstSuffix, to: node.changing(prefix: suffix).merge(with: currentChild, combine: combine))
            return changing(children: newChildren)
        }
        let commonPrefix = node.prefix ~> prefix
        let nodeSuffix = node.prefix - commonPrefix
        let suffix = prefix - commonPrefix
        return Self(prefix: commonPrefix, value: nil, children: Box(ChildMap().setting(key: nodeSuffix.first!, to: node.changing(prefix: nodeSuffix)).setting(key: suffix.first!, to: changing(prefix: suffix))))
    }
}

extension ArrayTrieNode where Key == String, Value == Singleton {
    func parse(children: ChildMap, tokens: [ArrayTrieToken]) -> (ChildMap, [ArrayTrieToken])? {
        guard let firstToken = tokens.first else { return (children, []) }
        switch firstToken {
        case .close:
            return (children, Array(tokens.dropFirst()))
        case .other(let str):
            guard let result = ArrayTrieNode(prefix: [str], value: nil, children: Box(ChildMap())).parse(tokens: Array(tokens.dropFirst())) else { return nil }
            return parse(children: children.setting(key: str, to: result.0), tokens: result.1)
        default:
            return nil
        }
    }
    
    func parse(tokens: [ArrayTrieToken]) -> (Self, [ArrayTrieToken])? {
        guard let firstToken = tokens.first else { return nil }
        switch firstToken {
        case .open:
            guard let result = parse(children: children.value, tokens: Array(tokens.dropFirst())) else { return nil }
            return changing(children: result.0).parse(tokens: result.1)
        case .comma:
            guard let firstChild = children.value.getFirstElement() else { return (self.changing(value: Singleton.void), Array(tokens.dropFirst())) }
            if children.value.countGreaterOrEqual(to: 2) { return (self, Array(tokens.dropFirst())) }
            return (firstChild.1.changing(prefix: prefix + firstChild.1.prefix), Array(tokens.dropFirst()))
        case .close:
            guard let firstChild = children.value.getFirstElement() else { return (self.changing(value: Singleton.void), Array(tokens.dropFirst())) }
            if children.value.countGreaterOrEqual(to: 2) { return (self, Array(tokens.dropFirst())) }
            return (firstChild.1.changing(prefix: prefix + firstChild.1.prefix), tokens)
        default:
            return nil
        }
    }
}
