import Foundation
import Nimble
import Quick
import Bedrock
@testable import persistent_collections

final class Persistent_Collections_Tests: QuickSpec {
    override func spec() {
        describe("Persistent Map") {
            let keyValuePairs = (0...1000).map { _ in (UUID.init().uuidString.dropRandom(), UUID.init().uuidString) }
            var map: PersistentMap<String, String> = PersistentMap<String, String>()
            it("can set and get") {
                let tuples = (0...1000).map { _ in (UUID.init().uuidString, UUID.init().uuidString) }
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
                for (key, _) in keyValuePairs {
                    map = map.deleting(key: key)
                    expect(map.get(key: key)).to(beNil())
                }
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
        }
    }
}

extension String {
    func dropRandom() -> String {
        let numberToDrop = Int.random(in: 0..<self.count-1)
        return String(self.dropFirst(numberToDrop))
    }
}

