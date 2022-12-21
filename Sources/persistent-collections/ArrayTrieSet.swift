import Foundation
import Bedrock

public struct ArrayTrieSet<Key: DataEncodable> {
    private typealias TrieRepresentation = ArrayTrie<Key, Singleton>
    private let trie: TrieRepresentation
    
    public init() {
        trie = TrieRepresentation()
    }
    
    private init(trie: TrieRepresentation) {
        self.trie = trie
    }
    
    public func isEmpty() -> Bool {
        return trie.isEmpty()
    }
    
    public func including(path: [Key]) -> Self {
        return Self(trie: trie.including(path: path))
    }
    
    public func excluding(path: [Key]) -> Self {
        return Self(trie: trie.excluding(path: path))
    }
    
    public func subtree(path: [Key]) -> Self {
        return Self(trie: trie.subtree(path: path))
    }
    
    public func supertree(path: [Key]) -> Self {
        return Self(trie: trie.supertree(path: path))
    }
    
    public func contains(_ keys: [Key]) -> Bool {
        return self.trie.get(keys: keys) != nil
    }
    
    public func adding(_ keys: [Key]) -> Self {
        return Self(trie: trie.setting(keys: keys, value: Singleton.void))
    }
    
    public func removing(_ keys: [Key]) -> Self {
        return Self(trie: trie.deleting(keys: keys))
    }
    
    public func overwrite(with other: Self) -> Self {
        return Self(trie: self.trie.overwrite(with: other.trie))
    }
    
    public func getChildKeys() -> [Key] {
        return trie.getChildKeys()
    }
}

extension ArrayTrieSet: Codable where Key: Codable & LosslessStringConvertible { }
