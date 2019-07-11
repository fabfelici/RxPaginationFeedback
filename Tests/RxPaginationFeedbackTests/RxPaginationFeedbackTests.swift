import XCTest
import RxFeedback
import RxTest
import RxSwift
import RxCocoa
import RxPaginationFeedback

class RxPaginationFeedbackTests: XCTestCase {

    var disposeBag: DisposeBag!
    var scheduler: TestScheduler!

    override func setUp() {
        disposeBag = DisposeBag()
        scheduler = TestScheduler(initialClock: 0, simulateProcessingDelay: false)
    }

    func testSimplePagination() {

        let loadNext = scheduler.createHotObservable([
            .next(1, ()),
            .next(2, ()),
        ]).asObservable()

        let dependencies = scheduler.createHotObservable([
            .next(0, 0),
            .next(3, 0)
        ]).asObservable()

        let stateObs = scheduler.createObserver(PaginationState<Int, Int>.self)

        let state: Observable<PaginationState<Int, Int>> = Observable.paginationSystem(
            scheduler: self.scheduler,
            dependencies: dependencies,
            loadNext: loadNext,
            pageProvider: SimplePageProvider(pageSize: 5).getPage
        )

        state
            .subscribe(stateObs)
            .disposed(by: disposeBag)

        scheduler.start()

        XCTAssertEqual(
            stateObs.events, [
                .next(0, .loading(nextDependency: 0, elements: [])),
                .next(0, .loaded(nextDependency: 5, elements: (1...5).map { $0 }, error: nil)),
                .next(1, .loading(nextDependency: 5, elements: (1...5).map { $0 })),
                .next(1, .loaded(nextDependency: 10, elements: (1...10).map { $0 }, error: nil)),
                .next(2, .loading(nextDependency: 10, elements: (1...10).map { $0 })),
                .next(2, .loaded(nextDependency: 15, elements: (1...15).map { $0 }, error: nil)),
                .next(3, .loading(nextDependency: 0, elements: [])),
                .next(3, .loaded(nextDependency: 5, elements: (1...5).map { $0 }, error: nil))
            ]
        )
    }

    func testDataSourceError() {

        let loadNext = scheduler.createHotObservable([
            .next(1, ())
        ]).asObservable()

        let stateObs = scheduler.createObserver(PaginationState<Int, Int>.self)
        let errorObs = scheduler.createObserver(String.self)

        let state = Observable.paginationSystem(
            scheduler: scheduler,
            dependencies: .just(0),
            loadNext: loadNext
        ) { _ -> Observable<Page<Int, Int>> in
            return .error(String.outOfBounds)
        }

        state
            .subscribe(stateObs)
            .disposed(by: disposeBag)

        state
            .compactMap { $0.error as? String }
            .subscribe(errorObs)
            .disposed(by: disposeBag)

        scheduler.start()

        XCTAssertEqual(
            stateObs.events, [
                .next(0, .loading(nextDependency: 0, elements: [])),
                .next(0, .loaded(nextDependency: 0, elements: [], error: String.outOfBounds)),
                .next(1, .loading(nextDependency: 0, elements: [])),
                .next(1, .loaded(nextDependency: 0, elements: [], error: String.outOfBounds))
            ]
        )

        XCTAssertEqual(
            errorObs.events, [
                .next(0, String.outOfBounds),
                .next(1, String.outOfBounds)
            ]
        )
    }

    func testDependency() {

        let loadNext = scheduler.createHotObservable([
            .next(2, ()),
        ]).asObservable()

        let dependencies = scheduler.createHotObservable([
            .next(1, "page1"),
            .next(3, "page3"),
        ]).asObservable()

        let stateObs = scheduler.createObserver(PaginationState<String, Int>.self)
        let data = [
            "page1" : [1, 2, 3, 4, 5],
            "page3": [6, 7, 8, 9, 10]
        ]
        let state: Observable<PaginationState<String, Int>> =
            Observable.paginationSystem(
                scheduler: self.scheduler,
                dependencies: dependencies,
                loadNext: loadNext
            ) { dependency -> Observable<Page<String, Int>> in
                .just(.init(nextDependency: "page2", elements: data[dependency, default: []]))
            }

        state
            .subscribe(stateObs)
            .disposed(by: disposeBag)

        scheduler.start()

        XCTAssertEqual(
            stateObs.events, [
                .next(1, .loading(nextDependency: "page1", elements: [])),
                .next(1, .loaded(nextDependency: "page2", elements: (1...5).map { $0 }, error: nil)),
                .next(2, .loading(nextDependency: "page2", elements: (1...5).map { $0 })),
                .next(2, .loaded(nextDependency: "page2", elements: (1...5).map { $0 }, error: nil)),
                .next(3, .loading(nextDependency: "page3", elements: [])),
                .next(3, .loaded(nextDependency: "page2", elements: (6...10).map { $0 }, error: nil))
            ]
        )
    }

    func testDependencyRequestCanceled() {

        let dependencies = scheduler.createHotObservable([
            .next(1, "page1"),
            .next(2, "page2"),
        ]).asObservable()

        let stateObs = scheduler.createObserver(PaginationState<String, Int>.self)
        let data = [
            "page1" : (1...5).map { $0 },
            "page2": (6...10).map { $0 }
        ]
        let state: Observable<PaginationState<String, Int>> =
            Observable.paginationSystem(
                scheduler: self.scheduler,
                dependencies: dependencies,
                loadNext: .empty()
            ) { dependency -> Observable<Page<String, Int>> in
                Observable.just(Page(nextDependency: nil, elements: data[dependency, default: []]))
                    .delay(.seconds(2), scheduler: self.scheduler)
            }

        state
            .subscribe(stateObs)
            .disposed(by: disposeBag)

        scheduler.start()

        XCTAssertEqual(
            stateObs.events, [
                .next(1, .loading(nextDependency: "page1", elements: [])),
                .next(2, .loading(nextDependency: "page2", elements: [])),
                .next(4, .loaded(nextDependency: nil, elements: (6...10).map { $0 }, error: nil))
            ]
        )
    }

    func testSimplePaginationUsingDriver() {
        SharingScheduler.mock(scheduler: scheduler, action: _testSimplePaginationUsingDriver)
    }

    func _testSimplePaginationUsingDriver() {
        let loadNext: Driver<Void> = scheduler.createHotObservable([
            .next(1, ()),
            .next(2, ())
        ]).asSharedSequence(onErrorDriveWith: .empty())

        let dependencies: Driver<Int> = scheduler.createHotObservable([
            .next(0, 0),
            .next(3, 0)
        ]).asSharedSequence(onErrorDriveWith: .empty())

        let stateObs = scheduler.createObserver(PaginationState<Int, Int>.self)

        let state: Driver<PaginationState<Int, Int>> =
            Driver.paginationSystem(
                dependencies: dependencies,
                loadNext: loadNext,
                pageProvider: SimplePageProvider(pageSize: 5).getPage
            )

        state
            .drive(stateObs)
            .disposed(by: disposeBag)

        scheduler.start()

        XCTAssertEqual(
            stateObs.events, [
                .next(0, .loading(nextDependency: 0, elements: [])),
                .next(0, .loaded(nextDependency: 5, elements: (1...5).map { $0 }, error: nil)),
                .next(1, .loading(nextDependency: 5, elements: (1...5).map { $0 })),
                .next(1, .loaded(nextDependency: 10, elements: (1...10).map { $0 }, error: nil)),
                .next(2, .loading(nextDependency: 10, elements: (1...10).map { $0 })),
                .next(2, .loaded(nextDependency: 15, elements: (1...15).map { $0 }, error: nil)),
                .next(3, .loading(nextDependency: 0, elements: [])),
                .next(3, .loaded(nextDependency: 5, elements: (1...5).map { $0 }, error: nil))
            ]
        )
    }
    
}

extension String: Error {
    static let outOfBounds = "Out of Bounds"
}

class SimplePageProvider {

    let data = (1...100).map { $0 }
    let pageSize: Int

    init(pageSize: Int) {
        self.pageSize = pageSize
    }

    func getPage(accumulatedCount: Int) -> Observable<Page<Int, Int>> {
        guard accumulatedCount + pageSize < data.count else { return .error(String.outOfBounds) }
        return Observable.just(
            Page(
                nextDependency: accumulatedCount + pageSize,
                elements: Array(data[accumulatedCount..<(accumulatedCount + pageSize)])
            )
        )
    }
}
