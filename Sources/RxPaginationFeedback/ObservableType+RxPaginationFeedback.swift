//
//  ObservableType+RxPaginationFeedback.swift
//  RxPaginationFeedback
//
//  Created by Felici, Fabio on 08/07/2019.
//

import RxSwift
import RxFeedback
import RxCocoa

public typealias PageProvider<PageDependency, Element> = (PageDependency) -> Observable<Page<PageDependency, Element>>

extension ObservableType where Element == Any {

    /**
         PageDependency:  Any type of information needed to fetch a page.
         Element: The accumulated elements during paging.

         - parameter dependencies: The dependecies needed to fetch pages.
         - parameter loadNext: Observable of load next trigger events.
         - parameter pageProvider: Provides observables of pages given a `PageDependency`.
            The operation is canceled If dependencies emits a new value.
         - returns: The pagination state.
         */

    public static func paginationSystem<PageDependency: Equatable, Element>(
        scheduler: ImmediateSchedulerType,
        dependencies: Observable<PageDependency>,
        loadNext: Observable<Void>,
        pageProvider: @escaping PageProvider<PageDependency, Element>
    ) -> Observable<PaginationState<PageDependency, Element>> {
        return dependencies
            .flatMapLatest {
                system(
                    initialState: .loading(nextDependency: $0, elements: []),
                    reduce: PaginationState.reduce,
                    scheduler: scheduler,
                    feedback: react(
                        request: { $0.loadNextPage },
                        effects: paginationEffect(pageProvider)
                    ),
                    { _ in
                        loadNext.map { .loadNext }
                    }
                )
            }
    }

}

extension SharedSequenceConvertibleType where Element == Any, SharingStrategy == DriverSharingStrategy {

    public static func paginationSystem<PageDependency: Equatable, Element>(
        dependencies: Driver<PageDependency>,
        loadNext: Driver<Void>,
        pageProvider: @escaping PageProvider<PageDependency, Element>
    ) -> Driver<PaginationState<PageDependency, Element>> {
        return dependencies
            .flatMapLatest {
                system(
                    initialState: .loading(nextDependency: $0, elements: []),
                    reduce: PaginationState.reduce,
                    feedback: react(
                        request: { $0.loadNextPage },
                        effects: {
                            paginationEffect(pageProvider)($0)
                                .asSignal(onErrorSignalWith: .empty())
                        }
                    ),
                    { _ in
                        loadNext.map { .loadNext }
                            .asSignal(onErrorSignalWith: .empty())
                    }
                )
            }
    }

}

fileprivate func paginationEffect<PageDependency, Element>(
    _ pageProvider: @escaping PageProvider<PageDependency, Element>
) -> (PageDependency) -> Observable<PaginationState<PageDependency, Element>.Event> {
    return {
        pageProvider($0)
            .materialize()
            .compactMap {
                ($0.element.map { .page($0) } ?? $0.error.map { .error($0) })
            }
    }
}
