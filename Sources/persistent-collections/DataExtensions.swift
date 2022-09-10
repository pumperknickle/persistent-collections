import Foundation

extension ArraySlice where Element == UInt8 {
    
    // return -3 if self starts with other
    // return -2 if other starts with self
    // return -1 if self == other
    // return number of similar starting elements
    func compare(idx: Int, other: Self, otherIdx: Int, countSimilar: Int) -> Int {
        if otherIdx >= other.count && idx >= self.count { return -1 }
        if otherIdx >= other.count { return -3 }
        if idx >= self.count { return -2 }
        if self[idx] == other[otherIdx] {
            return compare(idx: idx + 1, other: other, otherIdx: otherIdx + 1, countSimilar: countSimilar + 1)
        }
        return countSimilar
    }
    
    func startsWith(idx: Int, other: Self) -> Bool {
        if other.count > count - idx { return false }
        return startsWith(idx: idx, other: other, otherIdx: 0)
    }
    
    func startsWith(idx: Int, other: Self, otherIdx: Int) -> Bool {
        if otherIdx >= other.count {
            return true }
        if idx >= self.count {
            return false }
        if self[idx] == other[otherIdx] {
            return startsWith(idx: idx + 1, other: other, otherIdx: otherIdx + 1)
        }
        return false
    }
}
