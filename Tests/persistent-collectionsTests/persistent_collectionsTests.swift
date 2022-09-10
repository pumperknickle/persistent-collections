import Foundation
import Nimble
import Quick
import Bedrock
@testable import persistent_collections

final class Persistent_Collections_Tests: QuickSpec {
    override func spec() {
        describe("Map functionality") {
            let keyValuePairs = (0...100000).map { _ in (UUID.init().uuidString.dropRandom(), UUID.init().uuidString) }
            var map: PersistentMap<String, String> = PersistentMap<String, String>()
            it("set and get") {
                map = keyValuePairs.reduce(PersistentMap<String, String>()) { partialResult, tuple in
                    return partialResult.setting(key: tuple.0, to: tuple.1)
                }
                for keyValuePair in keyValuePairs {
                    expect(map.get(key: keyValuePair.0)).toNot(beNil())
                }
            }
            it("delete") {
                for (key, _) in keyValuePairs {
                    map = map.deleting(key: key)
                    expect(map.get(key: key)).to(beNil())
                }
            }
            let keyValuePairs2 = (0...100000).map { _ in (UUID.init().uuidString.dropRandom(), UUID.init().uuidString) }
            let map1 = keyValuePairs.reduce(PersistentMap<String, String>()) { partialResult, tuple in
                return partialResult.setting(key: tuple.0, to: tuple.1)
            }
            let map2 = keyValuePairs2.reduce(PersistentMap<String, String>()) { partialResult, tuple in
                return partialResult.setting(key: tuple.0, to: tuple.1)
            }
            it ("merge") {
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
        }
    }
}

extension String {
    func dropRandom() -> String {
        let numberToDrop = Int.random(in: 0..<self.count)
        return String(self.dropFirst(numberToDrop))
    }
}

