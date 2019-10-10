import XCTest
import RxFeedback
import RxTest
import RxSwift
import RxCocoa
@testable import RxPaginationFeedback

extension PaginationState: Equatable where PageDependency: Equatable, Element: Equatable {
    public static func == (lhs: PaginationState<PageDependency, Element>, rhs: PaginationState<PageDependency, Element>) -> Bool {
        return lhs.isLoading == rhs.isLoading
            && lhs.nextDependency == rhs.nextDependency
            && lhs.elements == rhs.elements
            && lhs.error.debugDescription == rhs.error.debugDescription
    }
}

class RxPaginationFeedbackTests: XCTestCase {

    var disposeBag: DisposeBag!
    var scheduler: TestScheduler!

    override func setUp() {
        disposeBag = DisposeBag()
        scheduler = TestScheduler(initialClock: 0, simulateProcessingDelay: false)
    }

    func testSimplePagination() {

        let stateObs = scheduler.createObserver(PaginationState<Int, Int>.self)

        scheduler.createHotObservable([
            .next(0, 0),
            .next(3, 0)
        ]).flatMapLatest {
            Observable.paginationSystem(
                scheduler: self.scheduler,
                initialDependency: $0,
                loadNext: self.scheduler.createHotObservable([
                    .next(1, ()),
                    .next(2, ())
                ]).asObservable(),
                pageProvider: SimplePageProvider(pageSize: 5).getPage
            )
        }
        .subscribe(stateObs)
        .disposed(by: disposeBag)

        scheduler.start()

        XCTAssertEqual(
            stateObs.events, [
                .next(0, .init(isLoading: true, nextDependency: 0, elements: [])),
                .next(0, .init(isLoading: false, nextDependency: 5, elements: (1...5).map { $0 })),
                .next(1, .init(isLoading: true, nextDependency: 5, elements: (1...5).map { $0 })),
                .next(1, .init(isLoading: false, nextDependency: 10, elements: (1...10).map { $0 })),
                .next(2, .init(isLoading: true, nextDependency: 10, elements: (1...10).map { $0 })),
                .next(2, .init(isLoading: false, nextDependency: 15, elements: (1...15).map { $0 })),
                .next(3, .init(isLoading: true, nextDependency: 0, elements: [])),
                .next(3, .init(isLoading: false, nextDependency: 5, elements: (1...5).map { $0 }))
            ]
        )
    }

    func testChangingDependency() {

        let stateObs = scheduler.createObserver(PaginationState<String, Int>.self)

        let data = [
            "page1" : (1...5).map { $0 },
            "page3": (6...10).map { $0 }
        ]

        scheduler.createHotObservable([
            .next(1, "page1"),
            .next(3, "page3")
        ])
        .flatMapLatest {
            Observable.paginationSystem(
                scheduler: self.scheduler,
                initialDependency: $0,
                loadNext: self.scheduler.createHotObservable([
                    .next(2, ())
                ]).asObservable()
            ) { dependency -> Observable<Page<String, Int>> in
                .just(.init(nextDependency: "page2", elements: data[dependency, default: []]))
            }
        }
        .subscribe(stateObs)
        .disposed(by: disposeBag)

        scheduler.start()

        XCTAssertEqual(
            stateObs.events, [
                .next(1, .init(isLoading: true, nextDependency: "page1", elements: [])),
                .next(1, .init(isLoading: false, nextDependency: "page2", elements: (1...5).map { $0 })),
                .next(2, .init(isLoading: true, nextDependency: "page2", elements: (1...5).map { $0 })),
                .next(2, .init(isLoading: false, nextDependency: "page2", elements: (1...5).map { $0 })),
                .next(3, .init(isLoading: true, nextDependency: "page3", elements: [])),
                .next(3, .init(isLoading: false, nextDependency: "page2", elements: (6...10).map { $0 })),
            ]
        )
    }

    func testDependencyRequestCanceled() {

        let stateObs = scheduler.createObserver(PaginationState<String, Int>.self)

        let data = [
            "page1": (1...5).map { $0 },
            "page2": (6...10).map { $0 }
        ]

        scheduler.createHotObservable([
            .next(1, "page1"),
            .next(2, "page2"),
        ]).flatMapLatest {
            Observable.paginationSystem(
                scheduler: self.scheduler,
                initialDependency: $0,
                loadNext: .empty()
            ) { dependency -> Observable<Page<String, Int>> in
                Observable.just(Page(nextDependency: nil, elements: data[dependency, default: []]))
                    .delay(.seconds(2), scheduler: self.scheduler)
            }
        }
        .subscribe(stateObs)
        .disposed(by: disposeBag)

        scheduler.start()

        XCTAssertEqual(
            stateObs.events, [
                .next(1, .init(isLoading: true, nextDependency: "page1", elements: [])),
                .next(2, .init(isLoading: true, nextDependency: "page2", elements: [])),
                .next(4, .init(isLoading: false, nextDependency: nil, elements: (6...10).map { $0 }))
            ]
        )
    }

    func testPageError() {

        let stateObs = scheduler.createObserver(PaginationState<Int, Int>.self)

        Observable.paginationSystem(
            scheduler: self.scheduler,
            initialDependency: 0,
            loadNext: self.scheduler.createHotObservable([
                .next(1, ())
            ]).asObservable(),
            pageProvider: SimplePageProvider(pageSize: 70).getPage
        )
        .subscribe(stateObs)
        .disposed(by: disposeBag)

        scheduler.start()

        XCTAssertEqual(
            stateObs.events, [
                .next(0, .init(isLoading: true, nextDependency: 0, elements: [])),
                .next(0, .init(isLoading: false, nextDependency: 70, elements: (1...70).map { $0 })),
                .next(1, .init(isLoading: true, nextDependency: 70, elements: (1...70).map { $0 })),
                .next(1, .init(isLoading: false, nextDependency: 70, elements: (1...70).map { $0 }, error: String.outOfBounds))
            ]
        )
    }

    func testSimplePaginationUsingDriver() {
        SharingScheduler.mock(scheduler: scheduler, action: _testSimplePaginationUsingDriver)
    }

    func _testSimplePaginationUsingDriver() {

        let stateObs = scheduler.createObserver(PaginationState<Int, Int>.self)

        scheduler.createHotObservable([
            .next(0, 0),
            .next(3, 0)
        ])
        .asDriver(onErrorJustReturn: 0)
        .flatMapLatest {
            Driver.paginationSystem(
                initialDependency: $0,
                loadNext: self.scheduler.createHotObservable([
                    .next(1, ()),
                    .next(2, ())
                ]).asDriver(onErrorJustReturn: ()),
                pageProvider: SimplePageProvider(pageSize: 5).getPage
            )
        }
        .drive(stateObs)
        .disposed(by: disposeBag)

        scheduler.start()

        XCTAssertEqual(
            stateObs.events, [
                .next(0, .init(isLoading: true, nextDependency: 0, elements: [])),
                .next(0, .init(isLoading: false, nextDependency: 5, elements: (1...5).map { $0 })),
                .next(1, .init(isLoading: true, nextDependency: 5, elements: (1...5).map { $0 })),
                .next(1, .init(isLoading: false, nextDependency: 10, elements: (1...10).map { $0 })),
                .next(2, .init(isLoading: true, nextDependency: 10, elements: (1...10).map { $0 })),
                .next(2, .init(isLoading: false, nextDependency: 15, elements: (1...15).map { $0 })),
                .next(3, .init(isLoading: true, nextDependency: 0, elements: [])),
                .next(3, .init(isLoading: false, nextDependency: 5, elements: (1...5).map { $0 }))
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
