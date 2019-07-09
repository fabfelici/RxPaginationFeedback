//
//  ObservableType+RxPaginationFeedback.swift
//  RxPaginationFeedback
//
//  Created by Felici, Fabio on 08/07/2019.
//

import RxSwift
import RxFeedback
import RxCocoa

public typealias PageProvider<PageDependency, Element> = (PageDependency) -> Observable<PageResponse<PageDependency, Element>>

extension ObservableType where Element == Any {

    public static func paginationSystem<PageDependency: Hashable, Element>(
        scheduler: ImmediateSchedulerType,
        pageProvider: @escaping PageProvider<PageDependency, Element>,
        userEvents: Observable<PaginationState<PageDependency, Element>.UserEvent>
    ) -> Observable<PaginationState<PageDependency, Element>> {
        return system(
            initialState: .loading(dependency: nil, elements: []),
            reduce: PaginationState.reduce,
            scheduler: scheduler,
            feedback: react(
                requests: requests,
                effects: paginationEffect(pageProvider)
            ),
            { _ in
                userEvents.map { .user($0) }
                    .observeOn(scheduler)
            }
        )
    }

}

extension SharedSequenceConvertibleType where Element == Any, SharingStrategy == DriverSharingStrategy {

    public static func paginationSystem<PageDependency: Hashable, Element>(
        pageProvider: @escaping PageProvider<PageDependency, Element>,
        userEvents: Observable<PaginationState<PageDependency, Element>.UserEvent>
    ) -> Driver<PaginationState<PageDependency, Element>> {
        return system(
            initialState: .loading(dependency: nil, elements: []),
            reduce: PaginationState.reduce,
            feedback: react(
                requests: requests,
                effects: {
                    paginationEffect(pageProvider)($0)
                        .asSignal(onErrorSignalWith: .empty())
                }
            )
            ,
            { _ in
                userEvents.map { .user($0) }
                    .observeOn(MainScheduler.asyncInstance)
                    .asSignal(onErrorSignalWith: .empty())
            }
        )
    }

}

fileprivate func paginationEffect<PageDependency, Element>(
    _ pageProvider: @escaping PageProvider<PageDependency, Element>
) -> (PageDependency) -> Observable<PaginationState<PageDependency, Element>.Event> {
    return {
        pageProvider($0)
            .materialize()
            .compactMap {
                ($0.element.map { .response($0) } ?? $0.error.map { .error($0) })
                    .map { .pageProvider($0) }
        }
    }
}

fileprivate func requests<Dependency, Element>(_ state: PaginationState<Dependency, Element>) -> Set<Dependency> {
    return state.dependency.flatMap { state.isLoading ? Set([$0]) : nil } ?? Set()
}
