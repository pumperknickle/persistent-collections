import Foundation
import Nimble
import Quick
import Bedrock
@testable import persistent_collections

final class Persistent_Collections_Tests: QuickSpec {
    override func spec() {
        describe("Basic functions") {
            let keyValuePairs = (0...10000).map { _ in (UUID.init().uuidString, UUID.init().uuidString) }
            var map: PersistentMap<String, String> = PersistentMap<String, String>()
            it("can set and get") {
                map = keyValuePairs.reduce(PersistentMap<String, String>()) { partialResult, tuple in
                    return partialResult.setting(key: tuple.0, to: tuple.1)
                }
                for keyValuePair in keyValuePairs {
                    expect(map.get(key: keyValuePair.0)).toNot(beNil())
                }
            }
            it("can delete") {
                for (key, _) in keyValuePairs {
                    map = map.deleting(key: key)
                    expect(map.get(key: key)).to(beNil())
                }
            }
        }
//            it("is great") {
//                expect(newMap.setting(key: key1, to: value1).setting(key: key2, to: value2).setting(key: key3, to: value3).setting(key: key1, to: value2).get(key: key1)).to(equal(value2))
//                expect(newMap.setting(key: key1, to: value1).setting(key: key2, to: value2).setting(key: key3, to: value3).setting(key: key2, to: value3).get(key: key2)).to(equal(value3))
//                expect(newMap.setting(key: key1, to: value1).setting(key: key2, to: value2).setting(key: key3, to: value3).deleting(key: key1).get(key: key1)).to(beNil())
//                expect(newMap.setting(key: key1, to: value1).setting(key: key2, to: value2).setting(key: key3, to: value3).deleting(key: key1)).to(equal(newMap.setting(key: key2, to: value2).setting(key: key3, to: value3)))
//                expect(newMap.setting(key: key1, to: value1).setting(key: key2, to: value2).setting(key: key3, to: value3).deleting(key: key2)).to(equal(newMap.setting(key: key1, to: value1).setting(key: key3, to: value3)))
//            }
//            let keyValuePairs = (0...20).map { ("\($0)" + UUID.init().uuidString, UUID.init().uuidString) }
//            it("should set") {
//                let map = keyValuePairs.reduce(PersistentMap<String, String>()) { partialResult, tuple in
//                    return partialResult.setting(key: tuple.0, to: tuple.1)
//                }
//                for keyValuePair in keyValuePairs {
//                    expect(map.get(key: keyValuePair.0)).toNot(beNil())
//                }
//            }
//        }
//        describe("should set and get") {
//
//        }
    }
}

