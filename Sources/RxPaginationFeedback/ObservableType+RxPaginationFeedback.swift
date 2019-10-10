import RxSwift
import RxFeedback
import RxCocoa

public typealias PageProvider<PageDependency, Element> = (PageDependency) -> Observable<Page<PageDependency, Element>>

extension ObservableType where Element == Any {

    /**
     Rx operator to handle pagination use cases.

     `PageDependency`: Any type of information needed to fetch a page.

     `Element`: The accumulated elements during paging.

     - parameter scheduler: The scheduler used to reduce the events.
     - parameter initialDependency: The initial dependency needed to fetch first page.
     - parameter loadNext: Observable of load next events.
     - parameter pageProvider: Provides observable of page given a `PageDependency`.
     - returns: The pagination state.
     */

    public static func paginationSystem<PageDependency: Equatable, Element>(
        scheduler: ImmediateSchedulerType,
        initialDependency: PageDependency,
        loadNext: Observable<Void>,
        pageProvider: @escaping PageProvider<PageDependency, Element>
    ) -> Observable<PaginationState<PageDependency, Element>> {
        return system(
            initialState: .init(nextDependency: initialDependency),
            reduce: PaginationState.reduce,
            scheduler: scheduler,
            feedback: react(
                request: { $0.loadNextPage },
                effects: paginationEffect(pageProvider)
            ),
            {
                $0.flatMapLatest {
                    $0.isLoading ? .empty() : loadNext
                }
                .map { .loadNext }
            }
        )
    }
}

extension SharedSequenceConvertibleType where Element == Any, SharingStrategy == DriverSharingStrategy {

    public static func paginationSystem<PageDependency: Equatable, Element>(
        initialDependency: PageDependency,
        loadNext: Driver<Void>,
        pageProvider: @escaping PageProvider<PageDependency, Element>
    ) -> Driver<PaginationState<PageDependency, Element>> {
        return system(
            initialState: .init(nextDependency: initialDependency),
            reduce: PaginationState.reduce,
            feedback: react(
                request: { $0.loadNextPage },
                effects: {
                    paginationEffect(pageProvider)($0)
                        .asSignal(onErrorSignalWith: .empty())
                }
            ),
            {
                $0.flatMapLatest {
                    $0.isLoading ? .empty() : loadNext
                }
                .map { .loadNext }
                .asSignal(onErrorSignalWith: .empty())
            }
        )
    }

}

func paginationEffect<PageDependency, Element>(
    _ pageProvider: @escaping PageProvider<PageDependency, Element>
) -> (PageDependency) -> Observable<PaginationState<PageDependency, Element>.Event> {
    return {
        pageProvider($0)
            .materialize()
            .compactMap {
                $0.element.map { .success($0) } ?? $0.error.map { .failure($0) }
            }
            .map { .page($0) }
        }
}
