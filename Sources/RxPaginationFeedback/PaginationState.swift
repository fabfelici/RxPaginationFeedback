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

    /**
         The User events consumed by the pagination system.
         - loadNext: Transitions the state machine to loading state.
         - dependency: Transitions the state machine to loading state refreshing all the elements.
         */

    public enum UserEvent {
        case loadNext
        case dependency(PageDependency)
    }

    /**
         Internal events consumed by the pagination system.
         - response: Sent when a page is fetched.
         - error: Sent when an error occurred while fetching a page.
         */

    enum PageProviderEvent {
        case response(PageResponse<PageDependency, Element>)
        case error(Error)
    }

    enum Event {
        case user(UserEvent)
        case pageProvider(PageProviderEvent)
    }

    case loading(dependency: PageDependency?, elements: [Element])
    case loaded(dependency: PageDependency?, elements: [Element], error: Error?)

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

    var dependency: PageDependency? {
        switch self {
        case let .loading(dependency, _),
             let .loaded(dependency, _, _):
            return dependency
        }
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
        case .user(.loadNext):
            if state.dependency == nil { return state }
            return .loading(dependency: state.dependency, elements: state.elements)
        case let .user(.dependency(dependency)):
            return .loading(dependency: dependency, elements: [])
        case .pageProvider:
            return state
        }
    }

    private static func reduceLoading(state: PaginationState, event: Event) -> PaginationState {
        switch event {
        case let .pageProvider(.response(response)):
            return .loaded(dependency: response.dependency, elements: state.elements + response.elements, error: nil)
        case let .pageProvider(.error(error)):
            return .loaded(dependency: state.dependency, elements: state.elements, error: error)
        case let .user(userAction):
            switch userAction {
            case let .dependency(dependency):
                return .loading(dependency: dependency, elements: [])
            case .loadNext:
                return state
            }
        }
    }
}

extension PaginationState: Equatable where Element: Equatable, PageDependency: Equatable {
    public static func ==(lhs: PaginationState, rhs: PaginationState) -> Bool {
        switch (lhs, rhs) {
        case (.loading, .loading),
             (.loaded, .loaded):
            return lhs.elements == rhs.elements
                && lhs.dependency == rhs.dependency
        default:
            return false
        }
    }
}
