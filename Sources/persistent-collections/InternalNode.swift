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
    
    func count() -> Int {
        return leaves.count + nodes.map { $0.value.count() }.reduce(0, +) + (value != nil ? 1 : 0)
    }
    
    func getValue() -> V? {
        return value
    }
    
    func getPathSegment() -> PathSegment {
        return self.pathSegment
    }
    
    func getChildren() -> [Node] {
        return nodes.map { Node.internalNode($0) } + leaves.map { Node.leafNode($0) }
    }
    
    static func combining(leftLeaf: LeafType, rightLeaf: LeafType, combine: (V, V) -> V) -> Node {
        return combining(key: rightLeaf.pathSegment, keyIndex: 0, value: rightLeaf.value, combine: combine, replace: true, leaf: leftLeaf)
    }
    
    static func combining(key: PathSegment, keyIndex: Int, value: V, combine: (V, V) -> V, replace: Bool, leaf: LeafType) -> Node {
        let prefixComparisonResult = key.compare(idx: keyIndex, other: leaf.pathSegment, otherIdx: 0, countSimilar: 0)
        switch prefixComparisonResult {
        case -3:
            let newIndex = keyIndex + leaf.pathSegment.count
            let next = key[newIndex]
            let newLeaf = LeafType(pathSegment: PathSegment(key.dropFirst(newIndex)), value: value)
            let newInternalNode = Box<Self>(Self(pathSegment: leaf.pathSegment, leafExistence: UInt256.zero.overwrite(byte: next, bit: true), nodeExistence: UInt256.zero, leaves: [newLeaf], nodes: [], value: leaf.value))
            return Node.internalNode(newInternalNode)
        case -2:
            let newIndex = key.count - keyIndex
            let next = leaf.pathSegment[newIndex]
            let newLeaf = LeafType(pathSegment: PathSegment(leaf.pathSegment.dropFirst(newIndex)), value: leaf.value)
            let newInternalNode = Box<Self>(Self(pathSegment: PathSegment(key.dropFirst(keyIndex)), leafExistence: UInt256.zero.overwrite(byte: next, bit: true), nodeExistence: UInt256.zero, leaves: [newLeaf], nodes: [], value: value))
            return Node.internalNode(newInternalNode)
        case -1:
            let newLeaf = LeafType(pathSegment: PathSegment(leaf.pathSegment), value: replace ? combine(leaf.value, value) : combine(value, leaf.value))
            return Node.leafNode(newLeaf)
        default:
            let parentPath = PathSegment(leaf.pathSegment.prefix(prefixComparisonResult))
            let oldChildPath = PathSegment(leaf.pathSegment.dropFirst(prefixComparisonResult))
            let newChildPath = PathSegment(key.dropFirst(keyIndex + prefixComparisonResult))
            let oldPivot = oldChildPath.first!
            let newPivot = newChildPath.first!
            let oldLeaf = LeafType(pathSegment: oldChildPath, value: leaf.value)
            let newLeaf = LeafType(pathSegment: newChildPath, value: value)
            let leaves = oldPivot > newPivot ? [newLeaf, oldLeaf] : [oldLeaf, newLeaf]
            let newLeafExistence = UInt256.zero.overwrite(byte: oldPivot, bit: true).overwrite(byte: newPivot, bit: true)
            let newInternalNode = Box<Self>(Self(pathSegment: parentPath, leafExistence: newLeafExistence, nodeExistence: UInt256.zero, leaves: leaves, nodes: [], value: nil))
            return Node.internalNode(newInternalNode)
        }
    }
    
    private func combining(leaf: LeafType, combine: (V, V) -> V, replace: Bool) -> Self {
        return combining(key: leaf.pathSegment, keyIndex: 0, value: leaf.value, combine: combine, replace: replace)
    }
    
    func combining(key: PathSegment, keyIndex: Int, value: V, combine: (V, V) -> V, replace: Bool) -> Self {
        let prefixComparisonResult = key.compare(idx: keyIndex, other: pathSegment, otherIdx: 0, countSimilar: 0)
        switch prefixComparisonResult {
        case -3:
            let newIndex = keyIndex + pathSegment.count
            let next = key[newIndex]
            if leafExistence.exists(byte: next) {
                let leafIndex = leafExistence.getStoredArrayIndex(byte: next) - 1
                let mergeResult = Self.combining(key: key, keyIndex: newIndex, value: value, combine: combine, replace: replace, leaf: leaves[leafIndex])
                switch mergeResult {
                case .internalNode(let internalNode):
                    return setInternalNode(at: next, node: internalNode)
                case .leafNode(let leafType):
                    return setLeafNode(at: next, node: leafType)
                }
            }
            if nodeExistence.exists(byte: next) {
                let nodeIndex = nodeExistence.getStoredArrayIndex(byte: next) - 1
                let childNode = nodes[nodeIndex]
                let settingResult = childNode.value.combining(key: key, keyIndex: newIndex, value: value, combine: combine, replace: replace)
                return setInternalNode(at: next, node: Box<Self>(settingResult))
            }
            return setLeafNode(at: next, node: LeafType(pathSegment: PathSegment(key.dropFirst(newIndex)), value: value))
        case -2:
            let parentPath = key.dropFirst(keyIndex)
            let next = pathSegment[parentPath.count]
            let newChildNode = Box<Self>(Self(pathSegment: PathSegment(pathSegment.dropFirst(parentPath.count)), leafExistence: leafExistence, nodeExistence: nodeExistence, leaves: leaves, nodes: nodes, value: self.value))
            let parentNode = InternalNode(pathSegment: PathSegment(parentPath), leafExistence: UInt256.zero, nodeExistence: UInt256.zero.overwrite(byte: next, bit: true), leaves: [], nodes: [newChildNode], value: value)
            return parentNode
        case -1:
            if self.value != nil {
                let newNode = InternalNode(pathSegment: pathSegment, leafExistence: leafExistence, nodeExistence: nodeExistence, leaves: leaves, nodes: nodes, value: replace ? value : self.value)
                return newNode
            }
            else {
                let newNode = InternalNode(pathSegment: pathSegment, leafExistence: leafExistence, nodeExistence: nodeExistence, leaves: leaves, nodes: nodes, value: value)
                return newNode
            }
        default:
            let parentPath = PathSegment(pathSegment.prefix(prefixComparisonResult))
            let oldPath = PathSegment(pathSegment.dropFirst(prefixComparisonResult))
            let newPath = PathSegment(key.dropFirst(keyIndex + prefixComparisonResult))
            let oldNext = oldPath.first!
            let newNext = newPath.first!
            let oldNode = Box<Self>(InternalNode(pathSegment: oldPath, leafExistence: leafExistence, nodeExistence: nodeExistence, leaves: leaves, nodes: nodes, value: self.value))
            let newLeaf = LeafType(pathSegment: newPath, value: value)
            let parentNode = InternalNode(pathSegment: parentPath, leafExistence: UInt256.zero.overwrite(byte: newNext, bit: true), nodeExistence: UInt256.zero.overwrite(byte: oldNext, bit: true), leaves: [newLeaf], nodes: [oldNode], value: nil)
            return parentNode
        }
    }
    
    private func setInternalNode(at byte: Atom, node: Box<Self>, newCount: Int? = nil) -> Self {
        let nodeIndex = nodeExistence.getStoredArrayIndex(byte: byte)
        if nodeExistence.exists(byte: byte) {
            let newNodes = nodes.replacing(element: node, at: nodeIndex - 1)
            return Self(pathSegment: pathSegment, leafExistence: leafExistence, nodeExistence: nodeExistence, leaves: leaves, nodes: newNodes, value: value)
        }
        let newNodes = nodes.inserting(element: node, at: nodeIndex)
        let newNodeExistence = nodeExistence.overwrite(byte: byte, bit: true)
        if leafExistence.exists(byte: byte) {
            let leafIndex = leafExistence.getStoredArrayIndex(byte: byte) - 1
            let newLeaves = leaves.removing(at: leafIndex)
            let newLeafExistence = leafExistence.overwrite(byte: byte, bit: false)
            return Self(pathSegment: pathSegment, leafExistence: newLeafExistence, nodeExistence: newNodeExistence, leaves: newLeaves, nodes: newNodes, value: value)
        }
        return Self(pathSegment: pathSegment, leafExistence: leafExistence, nodeExistence: newNodeExistence, leaves: leaves, nodes: newNodes, value: value)
    }
    
    private func setLeafNode(at byte: Atom, node: LeafType) -> Self {
        let leafIndex = leafExistence.getStoredArrayIndex(byte: byte)
        if leafExistence.exists(byte: byte) {
            let newLeaves = leaves.replacing(element: node, at: leafIndex - 1)
            return Self(pathSegment: pathSegment, leafExistence: leafExistence, nodeExistence: nodeExistence, leaves: newLeaves, nodes: nodes, value: value)
        }
        let newLeaves = leaves.inserting(element: node, at: leafIndex)
        let newLeafExistence = leafExistence.overwrite(byte: byte, bit: true)
        if nodeExistence.exists(byte: byte) {
            let nodeIndex = nodeExistence.getStoredArrayIndex(byte: byte) - 1
            let newNodes = nodes.removing(at: nodeIndex)
            let newNodeExistence = nodeExistence.overwrite(byte: byte, bit: false)
            return Self(pathSegment: pathSegment, leafExistence: newLeafExistence, nodeExistence: newNodeExistence, leaves: newLeaves, nodes: newNodes, value: value)
        }
        return Self(pathSegment: pathSegment, leafExistence: newLeafExistence, nodeExistence: nodeExistence, leaves: newLeaves, nodes: nodes, value: value)
    }
    
    // if return is nil, no key to delete
    // if return is not nil, a key was deleted
    func deleting(key: PathSegment, keyIndex: Int) -> Node? {
        if !key.startsWith(idx: keyIndex, other: pathSegment) { return nil }
        // removing value at this node
        let newIndex = keyIndex + pathSegment.count
        if key.count == newIndex {
            // Check if needs compaction
            if leaves.count == 1 && nodes.isEmpty {
                let oldLeaf = leaves.first!
                let newLeaf = LeafType(pathSegment: pathSegment + oldLeaf.pathSegment, value: oldLeaf.value)
                return Node.leafNode(newLeaf)
            }
            if leaves.isEmpty && nodes.count == 1 {
                let oldNode = nodes.first!.value
                let newNode = Box(InternalNode(pathSegment: pathSegment + oldNode.pathSegment, leafExistence: oldNode.leafExistence, nodeExistence: oldNode.nodeExistence, leaves: oldNode.leaves, nodes: oldNode.nodes, value: oldNode.value))
                return Node.internalNode(newNode)
            }
            // No compaction needed
            let newSelf = Box(Self(pathSegment: pathSegment, leafExistence: leafExistence, nodeExistence: nodeExistence, leaves: leaves, nodes: nodes, value: nil))
            return Node.internalNode(newSelf)
        }
        let next = key[newIndex]
        if nodeExistence.exists(byte: next) {
            let nodeIndex = nodeExistence.getStoredArrayIndex(byte: next) - 1
            let childResult = nodes[nodeIndex].value.deleting(key: key, keyIndex: newIndex)
            if let childResult = childResult {
                switch childResult {
                case .internalNode(let box):
                    let newNode = Box(setInternalNode(at: next, node: box))
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
            let childResult = leaves[leafIndex].deleting(key: key, keyIndex: newIndex)
            if childResult != nil { return nil }
            if leaves.count == 2 && nodes.isEmpty && value == nil {
                let otherIndex = leafIndex == 1 ? 0 : 1
                let oldLeaf = leaves[otherIndex]
                let newLeaf = LeafType(pathSegment: pathSegment + oldLeaf.pathSegment, value: oldLeaf.value)
                return Node.leafNode(newLeaf)
            }
            if leaves.count == 1 && nodes.count == 1 && value == nil {
                let oldNode = nodes.first!.value
                let newNode = Box(InternalNode(pathSegment: pathSegment + oldNode.pathSegment, leafExistence: oldNode.leafExistence, nodeExistence: oldNode.nodeExistence, leaves: oldNode.leaves, nodes: oldNode.nodes, value: oldNode.value))
                return Node.internalNode(newNode)
            }
            if leaves.count == 1 && nodes.isEmpty && value != nil {
                let newLeaf = LeafType(pathSegment: pathSegment, value: value!)
                return Node.leafNode(newLeaf)
            }
            let newLeaves = leaves.removing(at: leafIndex)
            let newLeafExistence = leafExistence.overwrite(byte: next, bit: false)
            let newNode = Box(InternalNode(pathSegment: pathSegment, leafExistence: newLeafExistence, nodeExistence: nodeExistence, leaves: newLeaves, nodes: nodes, value: value))
            return Node.internalNode(newNode)
        }
        return nil
    }
    
    func merging(other: Self, overwrite: (V, V) -> V) -> Self {
        let comparisonResult = self.pathSegment.compare(idx: 0, other: other.pathSegment, otherIdx: 0, countSimilar: 0)
        switch comparisonResult {
        case -3:
            let newIndex = other.pathSegment.count
            let newNode = Self(pathSegment: Data(pathSegment.dropFirst(newIndex)), leafExistence: leafExistence, nodeExistence: nodeExistence, leaves: leaves, nodes: nodes, value: value)
            let next = pathSegment[newIndex]
            if other.nodeExistence.exists(byte: next) {
                let nodeIndex = other.nodeExistence.getStoredArrayIndex(byte: next) - 1
                let childNode = other.nodes[nodeIndex].value
                let mergedNode = newNode.merging(other: childNode, overwrite: overwrite)
                let newOtherNodes = other.nodes.replacing(element: Box(mergedNode), at: nodeIndex)
                return Self(pathSegment: other.pathSegment, leafExistence: other.leafExistence, nodeExistence: other.nodeExistence, leaves: other.leaves, nodes: newOtherNodes, value: other.value)
            }
            if other.leafExistence.exists(byte: next) {
                let leafIndex = other.leafExistence.getStoredArrayIndex(byte: next) - 1
                let childLeaf = other.leaves[leafIndex]
                let newLeaves = other.leaves.removing(at: leafIndex)
                let newLeafExistence = other.leafExistence.overwrite(byte: next, bit: false)
                let addedNode = newNode.combining(key: childLeaf.pathSegment, keyIndex: 0, value: childLeaf.value, combine: overwrite, replace: true)
                let nodeIndex = other.nodeExistence.getStoredArrayIndex(byte: next)
                let newOtherNodes = other.nodes.inserting(element: Box(addedNode), at: nodeIndex)
                let newNodeExistence = other.nodeExistence.overwrite(byte: next, bit: true)
                return Self(pathSegment: other.pathSegment, leafExistence: newLeafExistence, nodeExistence: newNodeExistence, leaves: newLeaves, nodes: newOtherNodes, value: other.value)
            }
            let nodeIndex = other.nodeExistence.getStoredArrayIndex(byte: next)
            let newOtherNodes = other.nodes.inserting(element: Box(newNode), at: nodeIndex)
            let newNodeExistence = other.nodeExistence.overwrite(byte: next, bit: true)
            return Self(pathSegment: other.pathSegment, leafExistence: other.leafExistence, nodeExistence: newNodeExistence, leaves: other.leaves, nodes: newOtherNodes, value: other.value)
        case -2:
            let newIndex = pathSegment.count
            let newNode = Self(pathSegment: Data(other.pathSegment.dropFirst(newIndex)), leafExistence: other.leafExistence, nodeExistence: other.nodeExistence, leaves: other.leaves, nodes: other.nodes, value: other.value)
            let next = other.pathSegment[newIndex]
            if nodeExistence.exists(byte: next) {
                let nodeIndex = nodeExistence.getStoredArrayIndex(byte: next) - 1
                let childNode = nodes[nodeIndex].value
                let mergedNode = childNode.merging(other: newNode, overwrite: overwrite)
                let newOtherNodes = nodes.replacing(element: Box(mergedNode), at: nodeIndex)
                return Self(pathSegment: pathSegment, leafExistence: leafExistence, nodeExistence: nodeExistence, leaves: leaves, nodes: newOtherNodes, value: value)
            }
            if leafExistence.exists(byte: next) {
                let leafIndex = leafExistence.getStoredArrayIndex(byte: next) - 1
                let childLeaf = leaves[leafIndex]
                let newLeaves = leaves.removing(at: leafIndex)
                let newLeafExistence = leafExistence.overwrite(byte: next, bit: false)
                let addedNode = newNode.combining(key: childLeaf.pathSegment, keyIndex: 0, value: childLeaf.value, combine: overwrite, replace: false)
                let nodeIndex = nodeExistence.getStoredArrayIndex(byte: next)
                let newOtherNodes = nodes.inserting(element: Box(addedNode), at: nodeIndex)
                let newNodeExistence = nodeExistence.overwrite(byte: next, bit: true)
                return Self(pathSegment: pathSegment, leafExistence: newLeafExistence, nodeExistence: newNodeExistence, leaves: newLeaves, nodes: newOtherNodes, value: value)
            }
            let nodeIndex = nodeExistence.getStoredArrayIndex(byte: next)
            let newOtherNodes = nodes.inserting(element: Box(newNode), at: nodeIndex)
            let newNodeExistence = nodeExistence.overwrite(byte: next, bit: true)
            return Self(pathSegment: pathSegment, leafExistence: leafExistence, nodeExistence: newNodeExistence, leaves: leaves, nodes: newOtherNodes, value: value)
        case -1:
            return mergeNodes(other: other, overwrite: overwrite)
        default:
            let parentPath = PathSegment(pathSegment.prefix(comparisonResult))
            let selfChildPath = PathSegment(pathSegment.dropFirst(comparisonResult))
            let otherChildPath = PathSegment(other.pathSegment.dropFirst(comparisonResult))
            let selfNext = selfChildPath.first!
            let otherNext = otherChildPath.first!
            let newNodeExistence = UInt256(indices: [selfNext, otherNext])
            let newSelfNode = Box(Self(pathSegment: selfChildPath, leafExistence: leafExistence, nodeExistence: nodeExistence, leaves: leaves, nodes: nodes, value: value))
            let newOtherNode = Box(Self(pathSegment: otherChildPath, leafExistence: other.leafExistence, nodeExistence: other.nodeExistence, leaves: other.leaves, nodes: other.nodes, value: other.value))
            let newNodes = selfNext > otherNext ? [newOtherNode, newSelfNode] : [newSelfNode, newOtherNode]
            return Self(pathSegment: parentPath, leafExistence: UInt256.zero, nodeExistence: newNodeExistence, leaves: [], nodes: newNodes, value: nil)
        }
    }
   
    private func mergeNodes(other: Self, overwrite: (V, V) -> V) -> Self {
        let allLeaves = self.leafExistence | other.leafExistence
        let allInternal = self.nodeExistence | other.nodeExistence
        let allExistence = allLeaves | allInternal
        let allIdx = (allExistence).getIndices()
        let finalNodes = allIdx.map { idx -> (UInt8, Self?, LeafType?) in
            if allLeaves.exists(byte: idx) && allInternal.exists(byte: idx) {
                let selfLeafExists = self.leafExistence.exists(byte: idx)
                let leafTarget = selfLeafExists ? self : other
                let nodeTarget = selfLeafExists ? other : self
                let leafIdx = leafTarget.leafExistence.getStoredArrayIndex(byte: idx) - 1
                let nodeIdx = nodeTarget.nodeExistence.getStoredArrayIndex(byte: idx) - 1
                let leaf = leafTarget.leaves[leafIdx]
                let node = nodeTarget.nodes[nodeIdx].value
                let result = node.combining(leaf: leaf, combine: overwrite, replace: !selfLeafExists)
                return (idx, result, nil)
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
                        let result = Self.combining(leftLeaf: selfLeaf, rightLeaf: otherLeaf, combine: overwrite)
                        switch result {
                        case .leafNode(let leaf):
                            return (idx, nil, leaf)
                        case .internalNode(let intern):
                            return (idx, intern.value, nil)
                        }
                    }
                    return (idx, nil, selfLeaf)
                }
                let otherIdx = other.leafExistence.getStoredArrayIndex(byte: idx) - 1
                let otherLeaf = other.leaves[otherIdx]
                return (idx, nil, otherLeaf)
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
                    return (idx, result, nil)
                }
                return (idx, selfNode, nil)
            }
            let otherIdx = other.nodeExistence.getStoredArrayIndex(byte: idx) - 1
            let otherNode = other.nodes[otherIdx].value
            return (idx, otherNode, nil)
        }
        // TODO: could be optimized non-functionally
        let internalTuples = finalNodes.filter { $0.1 != nil }.map { ($0.0, $0.1!) }
        let leafTuples = finalNodes.filter { $0.2 != nil }.map { ($0.0, $0.2!) }
        let newNodeExistence = UInt256(indices: internalTuples.map { $0.0 })
        let newLeafExistence = UInt256(indices: leafTuples.map { $0.0 })
        let newNodes = internalTuples.map { Box($0.1) }
        let newLeaves = leafTuples.map { $0.1 }
        if let selfValue = self.value {
            if let otherValue = other.value {
                return Self(pathSegment: pathSegment, leafExistence: newLeafExistence, nodeExistence: newNodeExistence, leaves: newLeaves, nodes: newNodes, value: overwrite(selfValue, otherValue))
            }
            return Self(pathSegment: pathSegment, leafExistence: newLeafExistence, nodeExistence: newNodeExistence, leaves: newLeaves, nodes: newNodes, value: selfValue)
        }
        if let otherValue = other.value {
            return Self(pathSegment: pathSegment, leafExistence: newLeafExistence, nodeExistence: newNodeExistence, leaves: newLeaves, nodes: newNodes, value: otherValue)
        }
        return Self(pathSegment: pathSegment, leafExistence: newLeafExistence, nodeExistence: newNodeExistence, leaves: newLeaves, nodes: newNodes, value: nil)
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
        if index == count {
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
