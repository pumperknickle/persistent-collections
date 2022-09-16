import Foundation
import Bedrock

struct ArrayTrieNode<Key: DataEncodable, Value> {
//    typealias ChildMap = PersistentMap<Key, Self>
//    let prefix: [Key]!
//    let value: Value?
//    let children: Box<ChildMap>!
//    
//    func getChild(_ key: Key) -> Self? {
//        children.value.get(key: key)
//    }
//    
//    func changing(prefix: [Key]) -> Self {
//        Self(prefix: prefix, value: value, children: children)
//    }
//    
//    func changing(value: Value?) -> Self {
//        Self(prefix: prefix, value: value, children: children)
//    }
//    
//    func changing(children: ChildMap) -> Self {
//        Self(prefix: prefix, value: value, children: Box(children))
//    }
//    
//    func changing(child: Key, node: Self?) -> Self {
//        return node != nil ? changing(children: children.value.setting(key: child, to: node!)) : changing(children: children.value.deleting(key: child))
//    }
//    
//    func get(keys: [Key]) -> Value? {
//        if !keys.starts(with: prefix) { return nil }
//        let suffix = keys - prefix
//        guard let firstValue = suffix.first else { return value }
//        guard let childNode = getChild(firstValue) else { return nil }
//        return childNode.get(keys: suffix)
//    }
//    
//    func setting(keys: [Key], to value: Value) -> Self {
//        if keys.count >= prefix.count && keys.starts(with: prefix) {
//            let suffix = keys - prefix
//            guard let firstValue = suffix.first else { return changing(value: value) }
//            guard let childNode = getChild(firstValue) else { return changing(child: firstValue, node: Self(prefix: suffix, value: value, children: Box(ChildMap())))}
//            return changing(child: firstValue, node: childNode.setting(keys: suffix, to: value))
//        }
//        if prefix.count > keys.count && prefix.starts(with: keys) {
//            let suffix = prefix - keys
//            return Self(prefix: keys, value: value, children: Box(ChildMap().setting(key: suffix.first!, to: changing(prefix: suffix))))
//        }
//        let parentPrefix = keys ~> prefix
//        let newPrefix = keys - parentPrefix
//        let oldPrefix = prefix - parentPrefix
//        let newNode = Self(prefix: newPrefix, value: value, children: Box(ChildMap()))
//        let oldNode = changing(prefix: oldPrefix)
//        return Self(prefix: parentPrefix, value: nil, children: Box(ChildMap().setting(key: newPrefix.first!, to: newNode).setting(key: oldPrefix.first!, to: oldNode)))
//    }
//    
//    func deleting() -> Self? {
//        
//    }
}
