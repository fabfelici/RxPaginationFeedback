/**
The state machine used to represent a paging system. It has only two states, `loading` and `loaded` and contains logic to
reduce events.
- `elements`: The accumulated elements.
- `isLoading`: Indicates if a page is being fetched.
- `error`: The latest error received while fetching a page.
*/

public struct PaginationState<PageDependency, Element> {

    enum Event {
        case loadNext
        case page(Result<Page<PageDependency, Element>, Error>)
    }

    public private(set) var elements: [Element]
    public private(set) var isLoading: Bool
    public private(set) var error: Error?
    private(set) var nextDependency: PageDependency?

    var loadNextPage: PageDependency? {
        return isLoading ? nextDependency : nil
    }

    init(isLoading: Bool, nextDependency: PageDependency?, elements: [Element], error: Error? = nil) {
        self.isLoading = isLoading
        self.nextDependency = nextDependency
        self.elements = elements
        self.error = error
    }
    
    init(nextDependency: PageDependency) {
        isLoading = true
        self.nextDependency = nextDependency
        elements = []
    }

    static func reduce(state: PaginationState, event: Event) -> PaginationState {
        var newState = state
        state.isLoading ? reduceLoading(state: &newState, event: event) : reduceLoaded(state: &newState, event: event)
        return newState
    }

    private static func reduceLoaded(state: inout PaginationState, event: Event) {
        switch event {
        case .loadNext:
            state.error = nil
            state.isLoading = state.nextDependency.map { _ in true } ?? false
        case .page:
            break
        }
    }

    private static func reduceLoading(state: inout PaginationState, event: Event) {
        switch event {
        case let .page(result):
            state.isLoading = false
            switch result {
            case let .failure(error):
                state.error = error
            case let .success(page):
                state.nextDependency = page.nextDependency
                state.elements = state.elements + page.elements
            }
        case .loadNext:
            break
        }
    }
}
