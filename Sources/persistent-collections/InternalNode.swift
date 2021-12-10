import Foundation
import Bedrock

struct InternalNode<V> {
    typealias LeafType = LeafNode<V>
    typealias PathSegment = LeafType.PathSegment
    typealias Atom = PathSegment.Element
    
    private let pathSegment: PathSegment
    private let leafExistence: UInt256
    private let nodeExistence: UInt256
    private let leaves: [LeafType]
    private let nodes: [Box<Self>]
    private let value: V?
    private let count: Int
    
    func getCount() -> Int {
        return count
    }
    
    func get(key: PathSegment, keyIndex: Int) -> V? {
        if key.startsWith(idx: keyIndex, other: pathSegment) {
            let nextIndex = keyIndex + pathSegment.count
            if key.count == nextIndex { return value }
            let next = key[nextIndex]
            if leafExistence.exists(byte: next) {
                return leaves[leafExistence.getStoredArrayIndex(byte: next) - 1].get(key: key, keyIndex: nextIndex)
            }
            if nodeExistence.exists(byte: next) {
                return nodes[nodeExistence.getStoredArrayIndex(byte: next) - 1].value.get(key: key, keyIndex: nextIndex)
            }
        }
        return nil
    }
    
    static func combining(leftLeaf: LeafType, rightLeaf: LeafType, combine: (V, V) -> (V, Int), replace: Bool) -> Node {
        let prefixComparisonResult = rightLeaf.pathSegment.compare(idx: 0, other: leftLeaf.pathSegment, otherIdx: 0, countSimilar: 0)
        switch prefixComparisonResult {
        case -3:
            let newIndex = leftLeaf.pathSegment.count
            let next = rightLeaf.pathSegment[newIndex]
            let newInternalNode = Box<Self>(Self(pathSegment: leftLeaf.pathSegment, leafExistence: UInt256.zero.overwrite(byte: next, bit: true), nodeExistence: UInt256.zero, leaves: [rightLeaf], nodes: [], value: leftLeaf.value, count: rightLeaf.count + leftLeaf.count))
            return Node.internalNode(newInternalNode)
        case -2:
            let newIndex = rightLeaf.pathSegment.count
            let next = leftLeaf.pathSegment[newIndex]
            let newInternalNode = Box<Self>(Self(pathSegment: rightLeaf.pathSegment, leafExistence: UInt256.zero.overwrite(byte: next, bit: true), nodeExistence: UInt256.zero, leaves: [leftLeaf], nodes: [], value: rightLeaf.value, count: rightLeaf.count + leftLeaf.count))
            return Node.internalNode(newInternalNode)
        case -1:
            let combineResult = replace ? combine(leftLeaf.value, rightLeaf.value) : combine(rightLeaf.value, leftLeaf.value)
            let newLeaf = LeafType(pathSegment: leftLeaf.pathSegment, value: combineResult.0, count: combineResult.1)
            return Node.leafNode(newLeaf)
        default:
            let parentPath = PathSegment(leftLeaf.pathSegment.prefix(prefixComparisonResult))
            let oldChildPath = PathSegment(leftLeaf.pathSegment.dropFirst(prefixComparisonResult))
            let newChildPath = PathSegment(rightLeaf.pathSegment.dropFirst(prefixComparisonResult))
            let oldPivot = oldChildPath.first!
            let newPivot = newChildPath.first!
            let oldLeaf = LeafType(pathSegment: oldChildPath, value: leftLeaf.value, count: leftLeaf.count)
            let newLeaf = LeafType(pathSegment: newChildPath, value: rightLeaf.value, count: rightLeaf.count)
            let leaves = oldPivot > newPivot ? [newLeaf, oldLeaf] : [oldLeaf, newLeaf]
            let newLeafExistence = UInt256.zero.overwrite(byte: oldPivot, bit: true).overwrite(byte: newPivot, bit: true)
            let newInternalNode = Box<Self>(Self(pathSegment: parentPath, leafExistence: newLeafExistence, nodeExistence: UInt256.zero, leaves: leaves, nodes: [], value: nil, count: leftLeaf.count + rightLeaf.count))
            return Node.internalNode(newInternalNode)
        }
    }
    
    static func combining(key: PathSegment, keyIndex: Int, value: V, valueCount: Int, combine: (V, V) -> (V, Int), replace: Bool, leaf: LeafType) -> Node {
        let rightLeaf = LeafType(pathSegment: key, value: value, count: valueCount)
        return combining(leftLeaf: leaf, rightLeaf: rightLeaf, combine: combine, replace: replace)
    }
    
    func combining(leaf: LeafType, combine: (V, V) -> (V, Int), replace: Bool) -> (Self, Int) {
        return combining(key: leaf.pathSegment, keyIndex: 0, value: leaf.value, valueCount: leaf.count, combine: combine, replace: replace)
    }
    
    func combining(key: PathSegment, keyIndex: Int, value: V, valueCount: Int, combine: (V, V) -> (V, Int), replace: Bool) -> (Self, Int) {
        let prefixComparisonResult = key.compare(idx: keyIndex, other: pathSegment, otherIdx: 0, countSimilar: 0)
        switch prefixComparisonResult {
        case -3:
            let newIndex = keyIndex + pathSegment.count
            let next = key[newIndex]
            if leafExistence.exists(byte: next) {
                let leafIndex = leafExistence.getStoredArrayIndex(byte: next) - 1
                let mergeResult = Self.combining(key: key, keyIndex: newIndex, value: value, valueCount: valueCount, combine: combine, replace: replace, leaf: leaves[leafIndex])
                switch mergeResult {
                case .internalNode(let internalNode):
                    let newNode = setInternalNode(at: next, node: internalNode)
                    return (newNode, newNode.count)
                case .leafNode(let leafType):
                    let newNode = setLeafNode(at: next, node: leafType)
                    return (newNode, newNode.count)
                }
            }
            if nodeExistence.exists(byte: next) {
                let nodeIndex = nodeExistence.getStoredArrayIndex(byte: next) - 1
                let childNodeValue = nodes[nodeIndex].value
                let settingResult = childNodeValue.combining(key: key, keyIndex: newIndex, value: value, valueCount: valueCount, combine: combine, replace: replace)
                let newNode = setInternalNode(at: next, node: Box<Self>(settingResult.0), newCount: settingResult.1)
                return (newNode, newNode.count)
            }
            return (setLeafNode(at: next, node: LeafType(pathSegment: PathSegment(key.dropFirst(newIndex)), value: value, count: valueCount)), count + valueCount)
        case -2:
            let parentPath = key.dropFirst(keyIndex)
            let next = pathSegment[parentPath.count]
            let newChildNode = Box<Self>(Self(pathSegment: PathSegment(pathSegment.dropFirst(parentPath.count)), leafExistence: leafExistence, nodeExistence: nodeExistence, leaves: leaves, nodes: nodes, value: self.value, count: count))
            let parentNode = InternalNode(pathSegment: PathSegment(parentPath), leafExistence: UInt256.zero, nodeExistence: UInt256.zero.overwrite(byte: next, bit: true), leaves: [], nodes: [newChildNode], value: value, count: count + valueCount)
            return (parentNode, count + valueCount)
        case -1:
            if self.value != nil {
                let newNode = InternalNode(pathSegment: pathSegment, leafExistence: leafExistence, nodeExistence: nodeExistence, leaves: leaves, nodes: nodes, value: value, count: count + valueCount)
                return (newNode, newNode.count)
            }
            else {
                let combined = combine(value, self.value!)
                let newNode = InternalNode(pathSegment: pathSegment, leafExistence: leafExistence, nodeExistence: nodeExistence, leaves: leaves, nodes: nodes, value: combined.0, count: count + combined.1)
                return (newNode, newNode.count)
            }
        default:
            let parentPath = PathSegment(pathSegment.prefix(prefixComparisonResult))
            let oldPath = PathSegment(pathSegment.dropFirst(prefixComparisonResult))
            let newPath = PathSegment(key.dropFirst(keyIndex + prefixComparisonResult))
            let oldNext = oldPath.first!
            let newNext = newPath.first!
            let oldNode = Box<Self>(InternalNode(pathSegment: oldPath, leafExistence: leafExistence, nodeExistence: nodeExistence, leaves: leaves, nodes: nodes, value: self.value, count: count))
            let newLeaf = LeafType(pathSegment: newPath, value: value, count: valueCount)
            let parentNode = InternalNode(pathSegment: parentPath, leafExistence: UInt256.zero.overwrite(byte: newNext, bit: true), nodeExistence: UInt256.zero.overwrite(byte: oldNext, bit: true), leaves: [newLeaf], nodes: [oldNode], value: nil, count: count + valueCount)
            return (parentNode, parentNode.count)
        }
    }
    
    private func setInternalNode(at byte: Atom, node: Box<Self>, newCount: Int? = nil) -> Self {
        let nodeIndex = nodeExistence.getStoredArrayIndex(byte: byte)
        let newNodeCount = newCount ?? node.value.count
        if nodeExistence.exists(byte: byte) {
            let oldNodeCount = nodes[nodeIndex - 1].value.count
            let newNodes = nodes.replacing(element: node, at: nodeIndex - 1)
            return Self(pathSegment: pathSegment, leafExistence: leafExistence, nodeExistence: nodeExistence, leaves: leaves, nodes: newNodes, value: value, count: count - oldNodeCount + newNodeCount)
        }
        let newNodes = nodes.inserting(element: node, at: nodeIndex)
        let newNodeExistence = nodeExistence.overwrite(byte: byte, bit: true)
        if leafExistence.exists(byte: byte) {
            let leafIndex = leafExistence.getStoredArrayIndex(byte: byte) - 1
            let newLeaves = leaves.removing(at: leafIndex)
            let newLeafExistence = leafExistence.overwrite(byte: byte, bit: false)
            return Self(pathSegment: pathSegment, leafExistence: newLeafExistence, nodeExistence: newNodeExistence, leaves: newLeaves, nodes: newNodes, value: value, count: count - 1 + newNodeCount)
        }
        return Self(pathSegment: pathSegment, leafExistence: leafExistence, nodeExistence: newNodeExistence, leaves: leaves, nodes: newNodes, value: value, count: count + newNodeCount)
    }
    
    private func setLeafNode(at byte: Atom, node: LeafType) -> Self {
        let leafIndex = leafExistence.getStoredArrayIndex(byte: byte)
        if leafExistence.exists(byte: byte) {
            let newLeaves = leaves.replacing(element: node, at: leafIndex - 1)
            return Self(pathSegment: pathSegment, leafExistence: leafExistence, nodeExistence: nodeExistence, leaves: newLeaves, nodes: nodes, value: value, count: count)
        }
        let newLeaves = leaves.inserting(element: node, at: leafIndex)
        let newLeafExistence = leafExistence.overwrite(byte: byte, bit: true)
        if nodeExistence.exists(byte: byte) {
            let nodeIndex = nodeExistence.getStoredArrayIndex(byte: byte) - 1
            let oldNodeCount = nodes[nodeIndex].value.count
            let newNodes = nodes.removing(at: nodeIndex)
            let newNodeExistence = nodeExistence.overwrite(byte: byte, bit: false)
            return Self(pathSegment: pathSegment, leafExistence: newLeafExistence, nodeExistence: newNodeExistence, leaves: newLeaves, nodes: newNodes, value: value, count: count - oldNodeCount + 1)
        }
        return Self(pathSegment: pathSegment, leafExistence: newLeafExistence, nodeExistence: nodeExistence, leaves: newLeaves, nodes: nodes, value: value, count: count + 1)
    }
    
    // if return is nil, no key to delete
    // if return is not nil, a key was deleted
    func deleting(key: PathSegment, keyIndex: Int, deletion: (V) -> (V, Bool)?) -> Node? {
        if !key.startsWith(idx: keyIndex, other: pathSegment) { return nil }
        // removing value at this node
        let newIndex = keyIndex + pathSegment.count
        if key.count == newIndex {
            guard let value = value else { return nil }
            let newValue = deletion(value)
            if newValue == nil {
                // Check if needs compaction
                if leaves.count == 1 && nodes.isEmpty {
                    let oldLeaf = leaves.first!
                    let newLeaf = LeafType(pathSegment: pathSegment + oldLeaf.pathSegment, value: oldLeaf.value, count: 1)
                    return Node.leafNode(newLeaf)
                }
                if leaves.isEmpty && nodes.count == 1 {
                    let oldNode = nodes.first!.value
                    let newNode = Box(InternalNode(pathSegment: pathSegment + oldNode.pathSegment, leafExistence: oldNode.leafExistence, nodeExistence: oldNode.nodeExistence, leaves: oldNode.leaves, nodes: oldNode.nodes, value: oldNode.value, count: oldNode.count))
                    return Node.internalNode(newNode)
                }
            }
            // No compaction needed
            let newSelf = Box(Self(pathSegment: pathSegment, leafExistence: leafExistence, nodeExistence: nodeExistence, leaves: leaves, nodes: nodes, value: newValue!.0, count: newValue!.1 ? count - 1: count))
            return Node.internalNode(newSelf)
        }
        let next = key[newIndex]
        if nodeExistence.exists(byte: next) {
            let nodeIndex = nodeExistence.getStoredArrayIndex(byte: next) - 1
            let childResult = nodes[nodeIndex].value.deleting(key: key, keyIndex: newIndex, deletion: deletion)
            if let childResult = childResult {
                switch childResult {
                case .internalNode(let box):
                    let newNode = Box(setInternalNode(at: next, node: box, newCount: count - 1))
                    return Node.internalNode(newNode)
                case .leafNode(let leafType):
                    let newNode = Box(setLeafNode(at: next, node: leafType))
                    return Node.internalNode(newNode)
                }
            }
            return nil
        }
        if leafExistence.exists(byte: next) {
            let leafIndex = leafExistence.getStoredArrayIndex(byte: next) - 1
            let childResult = leaves[leafIndex].deleting(key: key, keyIndex: newIndex, deletion: deletion)
            if childResult != nil && !childResult!.1 { return nil }
            if let childResult = childResult {
                if !childResult.1 { return nil }
                
            }
            if leaves.count == 2 && nodes.isEmpty && value == nil {
                let otherIndex = leafIndex == 1 ? 0 : 1
                let oldLeaf = leaves[otherIndex]
                let newLeaf = LeafType(pathSegment: pathSegment + oldLeaf.pathSegment, value: oldLeaf.value, count: oldLeaf.count)
                return Node.leafNode(newLeaf)
            }
            if leaves.count == 1 && nodes.count == 1 && value == nil {
                let oldNode = nodes.first!.value
                let newNode = Box(InternalNode(pathSegment: pathSegment + oldNode.pathSegment, leafExistence: oldNode.leafExistence, nodeExistence: oldNode.nodeExistence, leaves: oldNode.leaves, nodes: oldNode.nodes, value: oldNode.value, count: oldNode.count))
                return Node.internalNode(newNode)
            }
            if leaves.count == 1 && nodes.isEmpty && value != nil {
                let oldLeaf = leaves.first!
                let result = oldLeaf.deleting(key: key, keyIndex: newIndex, deletion: deletion)
                guard let result = result else {
                    let newLeaf = LeafType(pathSegment: pathSegment, value: value!, count: count - oldLeaf.count)
                    return Node.leafNode(newLeaf)
                }
                if !result.1 { return nil }
                let newNode = setLeafNode(at: next, node: result.0)
                return Node.internalNode(Box(newNode))
            }
        }
        return nil
    }
    
    func merging(other: Self, overwrite: (V, V) -> (V, Int)) -> Self {
        let comparisonResult = self.pathSegment.compare(idx: 0, other: other.pathSegment, otherIdx: 0, countSimilar: 0)
        switch comparisonResult {
        case -3:
            let newIndex = other.pathSegment.count
            let newNode = Self(pathSegment: pathSegment.dropFirst(newIndex), leafExistence: leafExistence, nodeExistence: nodeExistence, leaves: leaves, nodes: nodes, value: value, count: count)
            let next = pathSegment[newIndex]
            if other.nodeExistence.exists(byte: next) {
                let nodeIndex = other.nodeExistence.getStoredArrayIndex(byte: next) - 1
                let childNode = other.nodes[nodeIndex].value
                let mergedNode = newNode.merging(other: childNode, overwrite: overwrite)
                let newOtherNodes = other.nodes.replacing(element: Box(mergedNode), at: nodeIndex)
                return Self(pathSegment: other.pathSegment, leafExistence: other.leafExistence, nodeExistence: other.nodeExistence, leaves: other.leaves, nodes: newOtherNodes, value: other.value, count: other.count + mergedNode.count - childNode.count)
            }
            let nodeIndex = other.nodeExistence.getStoredArrayIndex(byte: next)
            let newOtherNodes = other.nodes.replacing(element: Box(newNode), at: nodeIndex)
            return Self(pathSegment: other.pathSegment, leafExistence: other.leafExistence, nodeExistence: other.nodeExistence, leaves: other.leaves, nodes: newOtherNodes, value: other.value, count: other.count + newOtherNodes.count)
        case -2:
            let newIndex = pathSegment.count
            let newNode = Self(pathSegment: other.pathSegment.dropFirst(newIndex), leafExistence: other.leafExistence, nodeExistence: other.nodeExistence, leaves: other.leaves, nodes: other.nodes, value: other.value, count: other.count)
            let next = other.pathSegment[newIndex]
            if nodeExistence.exists(byte: next) {
                let nodeIndex = nodeExistence.getStoredArrayIndex(byte: next) - 1
                let childNode = nodes[nodeIndex].value
                let mergedNode = childNode.merging(other: newNode, overwrite: overwrite)
                let newOtherNodes = nodes.replacing(element: Box(mergedNode), at: nodeIndex)
                return Self(pathSegment: pathSegment, leafExistence: leafExistence, nodeExistence: nodeExistence, leaves: leaves, nodes: newOtherNodes, value: value, count: count + mergedNode.count - childNode.count)
            }
            let nodeIndex = nodeExistence.getStoredArrayIndex(byte: next)
            let newOtherNodes = nodes.replacing(element: Box(newNode), at: nodeIndex)
            return Self(pathSegment: pathSegment, leafExistence: leafExistence, nodeExistence: nodeExistence, leaves: leaves, nodes: newOtherNodes, value: value, count: count + newOtherNodes.count)
        case -1:
            return mergeNodes(other: other, overwrite: overwrite)
        default:
            let parentPath = PathSegment(pathSegment.prefix(comparisonResult))
            let selfChildPath = PathSegment(pathSegment.dropFirst(comparisonResult))
            let otherChildPath = PathSegment(other.pathSegment.dropFirst(comparisonResult))
            let selfNext = selfChildPath.first!
            let otherNext = otherChildPath.first!
            let newNodeExistence = UInt256(indices: [selfNext, otherNext])
            let newSelfNode = Box(Self(pathSegment: selfChildPath, leafExistence: leafExistence, nodeExistence: nodeExistence, leaves: leaves, nodes: nodes, value: value, count: count))
            let newOtherNode = Box(Self(pathSegment: otherChildPath, leafExistence: other.leafExistence, nodeExistence: other.nodeExistence, leaves: other.leaves, nodes: other.nodes, value: other.value, count: other.count))
            let newNodes = selfNext > otherNext ? [newOtherNode, newSelfNode] : [newSelfNode, newOtherNode]
            return Self(pathSegment: parentPath, leafExistence: UInt256.zero, nodeExistence: newNodeExistence, leaves: [], nodes: newNodes, value: nil, count: count + other.count)
        }
    }
   
    func mergeNodes(other: Self, overwrite: (V, V) -> (V, Int)) -> Self {
        let allLeaves = self.leafExistence | other.leafExistence
        let allInternal = self.nodeExistence | other.nodeExistence
        let allExistence = allLeaves | allInternal
        let allIdx = (allExistence).getIndices()
        let finalNodes = allIdx.map { idx -> (UInt8, Self?, LeafType?, Int) in
            if allLeaves.exists(byte: idx) && allInternal.exists(byte: idx) {
                let selfLeafExists = self.leafExistence.exists(byte: idx)
                let leafTarget = selfLeafExists ? self : other
                let nodeTarget = selfLeafExists ? other : self
                let leafIdx = leafTarget.leafExistence.getStoredArrayIndex(byte: idx) - 1
                let nodeIdx = nodeTarget.nodeExistence.getStoredArrayIndex(byte: idx) - 1
                let leaf = leafTarget.leaves[leafIdx]
                let node = nodeTarget.nodes[nodeIdx].value
                let result = node.combining(leaf: leaf, combine: overwrite, replace: !selfLeafExists)
                return (idx, result.0, nil, result.1)
            }
            if allLeaves.exists(byte: idx) {
                let selfLeafExists = self.leafExistence.exists(byte: idx)
                if selfLeafExists {
                    let selfIdx = self.leafExistence.getStoredArrayIndex(byte: idx) - 1
                    let selfLeaf = self.leaves[selfIdx]
                    let otherLeafExists = other.leafExistence.exists(byte: idx)
                    if otherLeafExists {
                        let otherIdx = other.leafExistence.getStoredArrayIndex(byte: idx) - 1
                        let otherLeaf = other.leaves[otherIdx]
                        let result = Self.combining(leftLeaf: selfLeaf, rightLeaf: otherLeaf, combine: overwrite, replace: true)
                        switch result {
                        case .leafNode(let leaf):
                            return (idx, nil, leaf, leaf.count)
                        case .internalNode(let intern):
                            return (idx, intern.value, nil, selfLeaf.count + otherLeaf.count)
                        }
                    }
                    return (idx, nil, selfLeaf, selfLeaf.count)
                }
                let otherIdx = other.leafExistence.getStoredArrayIndex(byte: idx) - 1
                let otherLeaf = other.leaves[otherIdx]
                return (idx, nil, otherLeaf, otherLeaf.count)
            }
            let selfNodeExists = self.nodeExistence.exists(byte: idx)
            if selfNodeExists {
                let selfIdx = self.nodeExistence.getStoredArrayIndex(byte: idx) - 1
                let selfNode = self.nodes[selfIdx].value
                let otherNodeExists = other.nodeExistence.exists(byte: idx)
                if otherNodeExists {
                    let otherIdx = other.nodeExistence.getStoredArrayIndex(byte: idx) - 1
                    let otherNode = other.nodes[otherIdx].value
                    let result = selfNode.merging(other: otherNode, overwrite: overwrite)
                    return (idx, result, nil, result.count)
                }
                return (idx, selfNode, nil, selfNode.count)
            }
            let otherIdx = other.nodeExistence.getStoredArrayIndex(byte: idx) - 1
            let otherNode = other.nodes[otherIdx].value
            return (idx, otherNode, nil, otherNode.count)
        }
        // TODO: could be optimized non-functionally
        let internalTuples = finalNodes.filter { $0.1 != nil }.map { ($0.0, $0.1!, $0.3) }
        let leafTuples = finalNodes.filter { $0.2 != nil }.map { ($0.0, $0.2!, $0.3) }
        let newNodeExistence = UInt256(indices: internalTuples.map { $0.0 })
        let newLeafExistence = UInt256(indices: leafTuples.map { $0.0 })
        let newNodes = internalTuples.map { Box($0.1) }
        let newLeaves = leafTuples.map { $0.1 }
        let childCounts = newLeaves.map { $0.count }.reduce(0, +) + (internalTuples.map { $0.2 }.reduce(0, +))
        if let selfValue = self.value {
            if let otherValue = other.value {
                return Self(pathSegment: pathSegment, leafExistence: newLeafExistence, nodeExistence: newNodeExistence, leaves: newLeaves, nodes: newNodes, value: overwrite(selfValue, otherValue).0, count: childCounts + overwrite(selfValue, otherValue).1)
            }
            return Self(pathSegment: pathSegment, leafExistence: newLeafExistence, nodeExistence: newNodeExistence, leaves: newLeaves, nodes: newNodes, value: selfValue, count: childCounts + overwrite(selfValue, selfValue).1)
        }
        if let otherValue = other.value {
            return Self(pathSegment: pathSegment, leafExistence: newLeafExistence, nodeExistence: newNodeExistence, leaves: newLeaves, nodes: newNodes, value: otherValue, count: childCounts + overwrite(otherValue, otherValue).1)
        }
        return Self(pathSegment: pathSegment, leafExistence: newLeafExistence, nodeExistence: newNodeExistence, leaves: newLeaves, nodes: newNodes, value: nil, count: childCounts)
    }
    
    enum Node {
        case internalNode(Box<InternalNode<V>>)
        case leafNode(LeafType)
    }
}

let rightHand = (UInt256.max/2) + 1

extension UInt256 {
    init(indices: [UInt8]) {
        self = indices.reduce(Self.zero) { partialResult, idx in
            return partialResult.overwrite(byte: idx, bit: true)
        }
    }
    
    func exists(byte: UInt8) -> Bool {
        return ((self << Int(byte)) & rightHand) == rightHand
    }
    
    fileprivate func overwrite(byte: UInt8, bit: Bool) -> Self {
        if bit {
            return self | (rightHand >> Int(byte))
        }
        else {
            return self & ~(rightHand >> Int(byte))
        }
    }
    
    fileprivate func getStoredArrayIndex(byte: UInt8) -> Int {
        return (self >> (UInt8.max - byte)).nonzeroBitCount
    }
    
    public func getIndices() -> [UInt8] {
        var currentIdx = UInt8.zero
        var currentIndices = [UInt8]()
        currentIndices.reserveCapacity(nonzeroBitCount)
        var current = self
        while (current != Self.zero) {
            let leadingZeroBitCount = current.leadingZeroBitCount
            currentIdx += UInt8(leadingZeroBitCount)
            currentIndices.append(currentIdx)
            if currentIdx == UInt8.max { return currentIndices }
            currentIdx += 1
            current = current << (leadingZeroBitCount + 1)
        }
        return currentIndices
    }
}

extension InternalNode: Equatable where V: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        if lhs.nodeExistence != rhs.nodeExistence || lhs.leafExistence != rhs.leafExistence { return false }
        return lhs.nodes == rhs.nodes && lhs.leaves == rhs.leaves
    }
}

extension Array {
    @inlinable
    @inline(__always)
    func removing(at index: Int) -> Self {
        if index == 0 {
            return Array(dropFirst())
        }
        if index == count - 1 {
            return Array(dropLast())
        }
        return Array(self[0..<index] + self[(index+1)..<self.count])
    }
    
    @inlinable
    @inline(__always)
    func inserting(element: Element, at index: Int) -> Self {
        if index == 0 {
            return [element] + self
        }
        if index == count - 1 {
            return self + [element]
        }
        return Array(self[0..<index] + [element] + self[index..<self.count])
    }
    
    @inlinable
    @inline(__always)
    func replacing(element: Element, at index: Int) -> Self {
        if index == 0 {
            return Array([element] + self.dropFirst())
        }
        if index == count - 1 {
            return Array(self.dropLast() + [element])
        }
        return Array(self[0..<index] + [element] + self[index+1..<self.count])
    }
}
