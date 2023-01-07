import Foundation
import Bedrock

// Nearest ancestor value array trie
public struct NAVArrayTrie<Key: DataEncodable, Value> {
    public typealias TrieType = ArrayTrie<Key, Value>
    let trie: ArrayTrie<Key, Value>
    let rootAncestorValue: Value?
    
    public init(trie: TrieType, rootAncestorValue: Value?) {
        self.trie = trie
        self.rootAncestorValue = rootAncestorValue
    }
    
    public var ancestorValue: Value? { return rootAncestorValue }
    
    public func subtreeWithCover(keys: [Key]) -> Self {
        guard let firstKey = keys.first else { return self }
        guard let childNode = trie.children.get(key: firstKey) else { return Self(trie: TrieType(), rootAncestorValue: rootAncestorValue) }
        guard let childResult = childNode.subtreeWithCover(keys: keys, current: rootAncestorValue) else { return Self(trie: TrieType(), rootAncestorValue: rootAncestorValue) }
        return Self(trie: TrieType(children: childResult.0), rootAncestorValue: childResult.1)
    }
    
    public func contains(key: Key) -> Bool {
        guard let childNode = trie.children.get(key: key) else { return false }
        return childNode.get(keys: [key]) != nil
    }
}
