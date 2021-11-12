import Foundation
import Nimble
import Quick
import Bedrock
@testable import persistent_collections

final class Persistent_Collections_Tests: QuickSpec {
    override func spec() {
        let newMap = PersistentMap<String, [[String]]>()
        let key1 = "foo"
        let value1 = [["fooValue"]]
        let key2 = "bar"
        let value2 = [["barValue"]]
        let key3 = "foobar"
        let value3 = [["boofar"]]
        describe("setup maps") {
            it("is great") {
                expect(newMap.setting(key: key1, to: value1).setting(key: key2, to: value2).setting(key: key3, to: value3).setting(key: key1, to: value2).get(key: key1)).to(equal(value2))
                expect(newMap.setting(key: key1, to: value1).setting(key: key2, to: value2).setting(key: key3, to: value3).setting(key: key2, to: value3).get(key: key2)).to(equal(value3))
                expect(newMap.setting(key: key1, to: value1).setting(key: key2, to: value2).setting(key: key3, to: value3).deleting(key: key1).get(key: key1)).to(beNil())
                expect(newMap.setting(key: key1, to: value1).setting(key: key2, to: value2).setting(key: key3, to: value3).deleting(key: key1)).to(equal(newMap.setting(key: key2, to: value2).setting(key: key3, to: value3)))
                expect(newMap.setting(key: key1, to: value1).setting(key: key2, to: value2).setting(key: key3, to: value3).deleting(key: key2)).to(equal(newMap.setting(key: key1, to: value1).setting(key: key3, to: value3)))
            }
        }
    }
}

