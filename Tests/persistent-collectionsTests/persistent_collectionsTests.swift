import Foundation
import Nimble
import Quick
import Bedrock
@testable import persistent_collections

final class Persistent_Collections_Tests: QuickSpec {
    override func spec() {
        let newMap = PersistentMap<String, String>()
        let key1 = "foo"
        let key2 = "bar"
        let key3 = "foobar"
        let key4 = "fod"
        let key5 = "car"
        let key6 = "dar"
        describe("Basic functions") {
            it("can set and get") {
//                let result1 = newMap.setting(key: key3, to: key3).setting(key: key1, to: key1)
//                expect(result1.get(key: key1)).toNot(beNil())
//                expect(result1.get(key: key1)).to(be(key1))
//                expect(result1.get(key: key3)).toNot(beNil())
//                expect(result1.get(key: key3)).to(be(key3))
//                let result2 = newMap.setting(key: key1, to: key1).setting(key: key4, to: key4)
//                expect(result2.get(key:key4)).toNot(beNil())
//                expect(result2.get(key:key1)).toNot(beNil())
//                expect(result2.get(key: key1)).to(be(key1))
//                expect(result2.get(key: key4)).to(be(key4))
//                let result3 = newMap.setting(key: key1, to: key1).setting(key: key3, to: key3)
//                expect(result3.get(key: key1)).toNot(beNil())
//                expect(result3.get(key: key1)).to(be(key1))
//                expect(result3.get(key: key3)).toNot(beNil())
//                expect(result3.get(key: key3)).to(be(key3))
                let result4 = newMap.setting(key: key1, to: key1).setting(key: key2, to: key2).setting(key: key5, to: key5)
                expect(result4.get(key: key1)).toNot(beNil())
                expect(result4.get(key: key1)).to(be(key1))
                expect(result4.get(key: key2)).toNot(beNil())
                expect(result4.get(key: key2)).to(be(key2))
                expect(result4.get(key: key5)).toNot(beNil())
                expect(result4.get(key: key5)).to(be(key5))
//                expect(result4.get(key: key6)).toNot(beNil())
//                expect(result4.get(key: key6)).to(be(key6))
            }
            let keyValuePairs = (0...100).map { _ in (UUID.init().uuidString, UUID.init().uuidString) }
            it("should set") {
                let map = keyValuePairs.reduce(PersistentMap<String, String>()) { partialResult, tuple in
                    return partialResult.setting(key: tuple.0, to: tuple.1)
                }
                for keyValuePair in keyValuePairs {
                    expect(map.get(key: keyValuePair.0)).toNot(beNil())
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

