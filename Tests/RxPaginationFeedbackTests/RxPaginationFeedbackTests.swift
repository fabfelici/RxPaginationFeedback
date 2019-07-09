import XCTest
import RxFeedback
import RxTest
import RxSwift
import RxPaginationFeedback

class RxPaginationFeedbackTests: XCTestCase {

    var disposeBag: DisposeBag!
    var scheduler: TestScheduler!

    override func setUp() {
        disposeBag = DisposeBag()
        scheduler = TestScheduler(initialClock: 0, simulateProcessingDelay: false)
    }

    func testSimplePagination() {

        let userEvents: Observable<PaginationState<Int, Int>.UserEvent> = scheduler.createHotObservable([
            .next(1, .dependency(0)),
            .next(2, .loadNext),
            .next(3, .loadNext),
            .next(4, .dependency(0))
        ]).asObservable()

        let stateObs = scheduler.createObserver(PaginationState<Int, Int>.self)

        let state: Observable<PaginationState<Int, Int>> = Observable.paginationSystem(
            scheduler: scheduler,
            pageProvider: SimplePageProvider(pageSize: 5, scheduler: scheduler).getPage,
            userEvents: userEvents
        )

        state
            .subscribe(stateObs)
            .disposed(by: disposeBag)

        scheduler.start()

        XCTAssertEqual(
            stateObs.events, [
                .next(0, .loading(dependency: nil, elements: [])),
                .next(1, .loading(dependency: 0, elements: [])),
                .next(1, .loaded(dependency: 5, elements: [1, 2, 3, 4, 5], error: nil)),
                .next(2, .loading(dependency: 5, elements: [1, 2, 3, 4, 5])),
                .next(2, .loaded(dependency: 10, elements: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10], error: nil)),
                .next(3, .loading(dependency: 10, elements: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10])),
                .next(3, .loaded(dependency: 15, elements: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15], error: nil)),
                .next(4, .loading(dependency: 0, elements: [])),
                .next(4, .loaded(dependency: 5, elements: [1, 2, 3, 4, 5], error: nil))
            ]
        )
    }

    func testDataSourceError() {

        let userEvents: Observable<PaginationState<Int, Int>.UserEvent> = scheduler.createHotObservable([
            .next(1, .dependency(0)),
            .next(2, .loadNext)
        ]).asObservable()


        let stateObs = scheduler.createObserver(PaginationState<Int, Int>.self)

        Observable.paginationSystem(
            scheduler: scheduler,
            pageProvider: { _ -> Observable<PageResponse<Int, Int>> in
                return .error(String.outOfBounds)
            },
            userEvents: userEvents
        )
        .subscribe(stateObs)
        .disposed(by: disposeBag)

        scheduler.start()

        XCTAssertEqual(
            stateObs.events, [
                .next(0, .loading(dependency: nil, elements: [])),
                .next(1, .loading(dependency: 0, elements: [])),
                .next(1, .loaded(dependency: 0, elements: [], error: String.outOfBounds)),
                .next(2, .loading(dependency: 0, elements: [])),
                .next(2, .loaded(dependency: 0, elements: [], error: String.outOfBounds))
            ]
        )
    }

    func testPageProviderEmptyPage() {

        let stateObs = scheduler.createObserver(PaginationState<Int, Int>.self)

        let state: Observable<PaginationState<Int, Int>> =  Observable.paginationSystem(
            scheduler: scheduler,
            pageProvider: { _ -> Observable<PageResponse<Int, Int>> in
                XCTFail("Should not be called")
                return .empty()
            },
            userEvents: .empty()
        )

        state
            .subscribe(stateObs)
            .disposed(by: disposeBag)

        scheduler.start()

        XCTAssertEqual(
            stateObs.events, [
                .next(0, .loading(dependency: nil, elements: []))
            ]
        )
    }

    func testDependency() {

        let userEvents: Observable<PaginationState<String, Int>.UserEvent> = scheduler.createHotObservable([
            .next(1, .dependency("page1")),
            .next(2, .loadNext),
            .next(3, .dependency("page3")),
        ]).asObservable()

        let stateObs = scheduler.createObserver(PaginationState<String, Int>.self)
        let data = [
            "page1" : [1, 2, 3, 4, 5],
            "page3": [6, 7, 8, 9, 10]
        ]
        let state: Observable<PaginationState<String, Int>> =  Observable.paginationSystem(
            scheduler: scheduler,
            pageProvider: { dependency -> Observable<PageResponse<String, Int>> in
                .just(.init(dependency: "page2", elements: data[dependency, default: []]))
            },
            userEvents: userEvents
        )

        state
            .subscribe(stateObs)
            .disposed(by: disposeBag)

        scheduler.start()

        XCTAssertEqual(
            stateObs.events, [
                .next(0, .loading(dependency: nil, elements: [])),
                .next(1, .loading(dependency: "page1", elements: [])),
                .next(1, .loaded(dependency: "page2", elements: [1, 2, 3, 4, 5], error: nil)),
                .next(2, .loading(dependency: "page2", elements: [1, 2, 3, 4, 5])),
                .next(2, .loaded(dependency: "page2", elements: [1, 2, 3, 4, 5], error: nil)),
                .next(3, .loading(dependency: "page3", elements: [])),
                .next(3, .loaded(dependency: "page2", elements: [6, 7, 8, 9, 10], error: nil))
            ]
        )
    }

    func testDependencyRequestCanceled() {

        let userEvents: Observable<PaginationState<String, Int>.UserEvent> = scheduler.createHotObservable([
            .next(1, .dependency("page1")),
            .next(2, .dependency("page2")),
        ]).asObservable()

        let stateObs = scheduler.createObserver(PaginationState<String, Int>.self)
        let data = [
            "page1" : [1, 2, 3, 4, 5],
            "page2": [6, 7, 8, 9, 10]
        ]
        let state: Observable<PaginationState<String, Int>> =  Observable.paginationSystem(
            scheduler: scheduler,
            pageProvider: { dependency -> Observable<PageResponse<String, Int>> in
                Observable.just(PageResponse.init(dependency: nil, elements: data[dependency, default: []]))
                    .delay(.seconds(2), scheduler: self.scheduler)
            },
            userEvents: userEvents
        )

        state
            .subscribe(stateObs)
            .disposed(by: disposeBag)

        scheduler.start()

        XCTAssertEqual(
            stateObs.events, [
                .next(0, .loading(dependency: nil, elements: [])),
                .next(1, .loading(dependency: "page1", elements: [])),
                .next(2, .loading(dependency: "page2", elements: [])),
                .next(4, .loaded(dependency: nil, elements: [6, 7, 8, 9, 10], error: nil))
            ]
        )
    }
}

extension String: Error {
    static let outOfBounds = "Out of Bounds"
}

class SimplePageProvider {

    let data = (1..<1000).map { $0 }
    let pageSize: Int
    let scheduler: SchedulerType

    init(pageSize: Int, scheduler: SchedulerType) {
        self.pageSize = pageSize
        self.scheduler = scheduler
    }

    func getPage(accumulatedCount: Int) -> Observable<PageResponse<Int, Int>> {
        guard accumulatedCount < data.count, accumulatedCount + pageSize < data.count else { return .error(String.outOfBounds) }
        return Observable.just(
            PageResponse(
                dependency: accumulatedCount + pageSize,
                elements: Array(data[accumulatedCount..<(accumulatedCount + pageSize)])
            )
        )
    }
}
