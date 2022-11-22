import Foundation

public struct LinkedList<Element> {
    private let tail: Box<(Element, Self)>?
    
    public init() {
        self.tail = nil
    }
    
    public init(tail: Box<(Element, Self)>?) {
        self.tail = tail
    }
    
    public init(array: [Element]) {
        var linkedList = Self()
        for element in array.reversed() {
            linkedList = Self(tail: Box((element, linkedList)))
        }
        self = linkedList
    }
    
    public func appending(element: Element) -> Self {
        return Self(tail: Box((element, self)))
    }
    
    public func toArray() -> [Element] {
        var arrayToReturn = Array<Element>()
        var current = tail
        while (current != nil) {
            let value = current!.value
            arrayToReturn.append(value.0)
            current = value.1.tail
        }
        return arrayToReturn.reversed()
    }
}
