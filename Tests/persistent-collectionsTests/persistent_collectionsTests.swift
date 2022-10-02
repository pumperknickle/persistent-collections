import Foundation
import Nimble
import Quick
import Bedrock
@testable import persistent_collections

final class Persistent_Collections_Tests: QuickSpec {
    override func spec() {
        describe("Persistent Array Trie") {
            let keyValuePairs: [([String], Int)] = (0...100).map { _ in
                let numberOfKeys = Int.random(in: 1...20)
                let keys: [String] = Array(repeating: 0, count: numberOfKeys).map { _ in String(Int.random(in: 0...10)) }
                let value = numberOfKeys
                return (keys, value)
            }
            let keyValuePairsWithFooPrefix: [([String], Int)] = (0...100).map { _ in
                let numberOfKeys = Int.random(in: 1...20)
                let keys: [String] = ["foo"] + Array(repeating: 0, count: numberOfKeys).map { _ in String(Int.random(in: 0...10)) }
                let value = numberOfKeys
                return (keys, value)
            }
            let keyValuePairsWithBarPrefix: [([String], Int)] = (0...100).map { _ in
                let numberOfKeys = Int.random(in: 1...20)
                let keys: [String] = ["bar"] + Array(repeating: 0, count: numberOfKeys).map { _ in String(Int.random(in: 0...10)) }
                let value = numberOfKeys
                return (keys, value)
            }
            let arrayTrie = keyValuePairs.reduce(ArrayTrie<String, Int>()) { result, element in
                return result.setting(keys: element.0, value: element.1)
            }
            it("can get elements") {
                let trie = keyValuePairs.reduce(ArrayTrie<String, Int>()) { result, element in
                    return result.setting(keys: element.0, value: element.1)
                }
                for tuple in trie.getElements() {
                    expect(trie.get(keys: tuple.0)).to(equal(tuple.1))
                }
            }
            it("count") {
                let keyValuePairsUnique: [([String], Int)] = (0...100).map { _ in
                    let numberOfKeys = Int.random(in: 1...20)
                    let keys: [String] = Array(repeating: 0, count: numberOfKeys).map { _ in UUID.init().uuidString }
                    let value = numberOfKeys
                    return (keys, value)
                }
                let uniqueTrie = keyValuePairsUnique.reduce(ArrayTrie<String, Int>()) { result, element in
                    return result.setting(keys: element.0, value: element.1)
                }
                expect(uniqueTrie.count).to(equal(keyValuePairsUnique.count))
            }
            it("can set and get") {
                for keyValuePair in keyValuePairs {
                    expect(arrayTrie.get(keys:keyValuePair.0)).to(equal(keyValuePair.1))
                }
            }
            it("supertree test") {
                let barSuperTree = arrayTrie.supertree(path: ["bar"])
                for keyValuePair in keyValuePairs {
                    expect(barSuperTree.get(keys:["bar"] + keyValuePair.0)).to(equal(keyValuePair.1))
                }
            }
            it("subtree test") {
                let barSuperTree = arrayTrie.supertree(path: ["bar"])
                let subtree = barSuperTree.subtree(path: ["bar"])
                for keyValuePair in keyValuePairs {
                    expect(subtree.get(keys:keyValuePair.0)).to(equal(keyValuePair.1))
                }
            }
            it("including") {
                let barFooTree = (keyValuePairsWithBarPrefix + keyValuePairsWithFooPrefix).reduce(ArrayTrie<String, Int>()) { result, element in
                    return result.setting(keys: element.0, value: element.1)
                }
                let barTree = barFooTree.including(path: ["bar"])
                for keyValuePair in keyValuePairsWithBarPrefix {
                    expect(barTree.get(keys:keyValuePair.0)).to(equal(keyValuePair.1))
                }
            }
            it("excluding") {
                let barFooTree = (keyValuePairsWithBarPrefix + keyValuePairsWithFooPrefix).reduce(ArrayTrie<String, Int>()) { result, element in
                    return result.setting(keys: element.0, value: element.1)
                }
                let fooTree = barFooTree.excluding(path: ["bar"])
                for keyValuePair in keyValuePairsWithFooPrefix {
                    expect(fooTree.get(keys:keyValuePair.0)).to(equal(keyValuePair.1))
                }
            }
        }
        describe("Persistent Map") {
            let keyValuePairs = (0...1000).map { _ in (UUID.init().uuidString.dropRandom(), UUID.init().uuidString) }
            var map: PersistentMap<String, String> = PersistentMap<String, String>()
            let tuples = (0...1000).map { _ in (UUID.init().uuidString, UUID.init().uuidString) }
            it("can set and get") {
                map = tuples.reduce(PersistentMap<String, String>()) { partialResult, tuple in
                    return partialResult.setting(key: tuple.0, to: tuple.1)
                }
                for tuple in tuples {
                    expect(map.get(key: tuple.0)).toNot(beNil())
                }
                var hashmap = Dictionary<String, String>()
                for tuple in tuples {
                    hashmap[tuple.0] = tuple.1
                }
                for key in hashmap.keys {
                    expect(map.get(key:key)).to(equal(hashmap[key]))
                }
            }
            it("can delete") {
                expect(map.count).to(equal(keyValuePairs.count))
                for (key, _) in tuples {
                    map = map.deleting(key: key)
                    expect(map.get(key: key)).to(beNil())
                }
                expect(map.count).to(equal(0))
            }
            let keyValuePairs2 = (0...1000).map { _ in (UUID.init().uuidString.dropRandom() + "R", UUID.init().uuidString) }
            let map1 = keyValuePairs.reduce(PersistentMap<String, String>()) { partialResult, tuple in
                return partialResult.setting(key: tuple.0, to: tuple.1)
            }
            let map2 = keyValuePairs2.reduce(PersistentMap<String, String>()) { partialResult, tuple in
                return partialResult.setting(key: tuple.0, to: tuple.1)
            }
            it ("can merge") {
                let result = map1.merge(other: map2) { s1, s2 in
                    return s2
                }
                for keyValuePair in keyValuePairs {
                    expect(result.get(key: keyValuePair.0)).toNot(beNil())
                }
                for keyValuePair in keyValuePairs2 {
                    expect(result.get(key: keyValuePair.0)).toNot(beNil())
                }
            }
            it("can get all elements") {
                let keyValuePairs3 = (0...1000).map { _ in (UUID.init().uuidString, UUID.init().uuidString) }
                let map3 = keyValuePairs3.reduce(PersistentMap<String, String>()) { partialResult, tuple in
                    return partialResult.setting(key: tuple.0, to: tuple.1)
                }
                let elements = map3.getElements()
                expect(elements.count).to(equal(keyValuePairs3.count))
                for (key, value) in elements {
                    expect(map3.get(key: key)).to(equal(value))
                }
                expect(map3.count).to(equal(keyValuePairs3.count))
            }
            let keyValuePairs3 = (0...1000).map { _ in (UUID.init().uuidString.dropRandom(), UUID.init().uuidString) }
            let keyValuePairs4 = (0...1000).map { _ in (UUID.init().uuidString.dropRandom(), UUID.init().uuidString) }
            let map3 = keyValuePairs3.reduce(PersistentMap<String, String>()) { partialResult, tuple in
                return partialResult.setting(key: tuple.0, to: tuple.1)
            }
            let map4 = keyValuePairs4.reduce(PersistentMap<String, String>()) { partialResult, tuple in
                return partialResult.setting(key: tuple.0, to: tuple.1)
            }
            it("can overwite") {
                let map5 = keyValuePairs4.reduce(map3) { partialResult, tuple in
                    let result = partialResult.setting(key: tuple.0, to: tuple.1)
                    expect(result.get(key:tuple.0)).to(equal(tuple.1))
                    return result
                }
                for (key, _) in keyValuePairs4 {
                    expect(map5.get(key:key)).to(equal(map4.get(key: key)))
                }
                let finalMap = map3.overwrite(with: map4)
                let elements = map4.getElements()
                for (key, value) in elements {
                    expect(finalMap.get(key: key)).to(equal(value))
                }
            }
            it("coding") {
                let map6 = PersistentMap<String, String>().setting(key: "a", to: "a").setting(key: "b", to: "b")
                let coded = try! JSONEncoder().encode(map6)
                let map7 = try! JSONDecoder().decode(PersistentMap<String, String>.self, from: coded)
                expect(map7).to(equal(map6))
            }
            it("count greater than") {
                let count1 = map1.getElements().count
                expect(map1.countGreaterOrEqual(to: count1)).to(beTrue())
                expect(map1.countGreaterOrEqual(to: count1 + 1)).to(beFalse())
                let count2 = map2.getElements().count
                expect(map2.countGreaterOrEqual(to: count2)).to(beTrue())
                expect(map2.countGreaterOrEqual(to: count2 + 1)).to(beFalse())
                let count3 = map3.getElements().count
                expect(map3.countGreaterOrEqual(to: count3)).to(beTrue())
                expect(map3.countGreaterOrEqual(to: count3 + 1)).to(beFalse())
                let count4 = map4.getElements().count
                expect(map4.countGreaterOrEqual(to: count4)).to(beTrue())
                expect(map4.countGreaterOrEqual(to: count4 + 1)).to(beFalse())
            }
            it("get first element") {
                let firstElement = map3.getFirstElement()
                expect(map3.get(key: firstElement!.0)).toNot(beNil())
            }
        }
    }
}

extension String {
    func dropRandom() -> String {
        let numberToDrop = Int.random(in: 0..<self.count-1)
        return String(self.dropFirst(numberToDrop))
    }
}

