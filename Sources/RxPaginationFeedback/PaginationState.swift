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
 - error: The latest error returned by the `pageProvider`.
 */

public enum PaginationState<PageDependency, Element> {

    enum Event {
        case loadNext
        case page(Page<PageDependency, Element>)
        case error(Error)
    }

    case loading(nextDependency: PageDependency?, elements: [Element])
    case loaded(nextDependency: PageDependency?, elements: [Element], error: Error?)

    public var elements: [Element] {
        switch self {
        case let .loading(_, elements),
             let .loaded(_, elements, _):
            return elements
        }
    }

    public var isLoading: Bool {
        switch self {
        case .loading:
            return true
        case .loaded:
            return false
        }
    }

    public var error: Error? {
        switch self {
        case let .loaded(_, _, error):
            return error
        case .loading:
            return nil
        }
    }

    var nextDependency: PageDependency? {
        switch self {
        case let .loading(dependency, _),
             let .loaded(dependency, _, _):
            return dependency
        }
    }

    var loadNextPage: PageDependency? {
        return isLoading ? nextDependency : nil
    }

    static func reduce(state: PaginationState, event: Event) -> PaginationState {
        switch state {
        case .loaded:
            return reduceLoaded(state: state, event: event)
        case .loading:
            return reduceLoading(state: state, event: event)
        }
    }

    private static func reduceLoaded(state: PaginationState, event: Event) -> PaginationState {
        switch event {
        case .loadNext:
            return state.nextDependency.map {
                .loading(nextDependency: $0, elements: state.elements)
            } ?? state
        case .error, .page:
            return state
        }
    }

    private static func reduceLoading(state: PaginationState, event: Event) -> PaginationState {
        switch event {
        case let .page(page):
            return .loaded(nextDependency: page.nextDependency, elements: state.elements + page.elements, error: nil)
        case let .error(error):
            return .loaded(nextDependency: state.nextDependency, elements: state.elements, error: error)
        case .loadNext:
            return state
        }
    }
}

extension PaginationState: Equatable where Element: Equatable, PageDependency: Equatable {
    public static func ==(lhs: PaginationState, rhs: PaginationState) -> Bool {
        switch (lhs, rhs) {
        case (.loading, .loading),
             (.loaded, .loaded):
            return lhs.elements == rhs.elements
                && lhs.nextDependency == rhs.nextDependency
        default:
            return false
        }
    }
}
