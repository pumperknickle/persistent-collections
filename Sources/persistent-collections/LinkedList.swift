import Foundation

struct LinkedList<Element> {
    private let tail: Box<(Element, Self)>?
    
    public init() {
        self.tail = nil
    }
    
    public init(tail: Box<(Element, Self)>?) {
        self.tail = tail
    }
    
    func appending(element: Element) -> Self {
        return Self(tail: Box((element, self)))
    }
    
    func toArray() -> [Element] {
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
