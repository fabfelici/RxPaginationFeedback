/**
The structure `PageProvider` function returns once a page has been fetched.
*/

public struct Page<Dependency, Element> {

    let nextDependency: Dependency?
    let elements: [Element]

    /**
     - parameter nextDependency: Any information required in order to fetch the next page.
     It will be passed to `pageProvider` when system needs to fetch a new page.
     Pass nil to indicate that no more pages are available.
     - parameter elements: The array of elements in the page.
     */

    public init(nextDependency: Dependency?, elements: [Element]) {
        self.nextDependency = nextDependency
        self.elements = elements
    }
}
