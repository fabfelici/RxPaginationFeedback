//
//  PaginationState.swift
//  RxPaginationFeedback
//
//  Created by Felici, Fabio on 08/07/2019.
//

/**
 The state machine used to represent a paging system. It has only two states, `loading` and `loaded` and contains logic to
 reduce events.
 - elements: The accumulated elements.
 - isLoading: Indicates if the system is currenlty fetching a page.
 */

public struct PaginationState<PageDependency, Element> {

    enum Event {
        case loadNext
        case page(Result<Page<PageDependency, Element>, Error>)
    }

    enum Status {
        case loading
        case loaded
    }

    private(set) var status: Status
    private(set) var nextDependency: PageDependency?
    private(set) var elements: [Element]

    var isLoading: Bool {
        switch status {
        case .loading:
            return true
        case .loaded:
            return false
        }
    }

    var loadNextPage: PageDependency? {
        return isLoading ? nextDependency : nil
    }

    init(nextDependency: PageDependency) {
        status = .loading
        self.nextDependency = nextDependency
        elements = []
    }

    static func reduce(state: PaginationState, event: Event) -> PaginationState {
        switch state.status {
        case .loaded:
            return reduceLoaded(state: state, event: event)
        case .loading:
            return reduceLoading(state: state, event: event)
        }
    }

    private static func reduceLoaded(state: PaginationState, event: Event) -> PaginationState {
        switch event {
        case .loadNext:
            var newState = state
            newState.status = state.nextDependency.map { _ in .loading } ?? .loaded
            return newState
        case .page:
            return state
        }
    }

    private static func reduceLoading(state: PaginationState, event: Event) -> PaginationState {
        switch event {
        case let .page(result):
            var newState = state
            newState.status = .loaded
            let page = try? result.get()
            newState.nextDependency = page?.nextDependency ?? state.nextDependency
            newState.elements = state.elements + (page?.elements ?? [])
            return newState
        case .loadNext:
            return state
        }
    }
}
