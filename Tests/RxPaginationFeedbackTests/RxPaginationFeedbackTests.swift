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

        let elementsObs = scheduler.createObserver([Int].self)

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
        .subscribe(elementsObs)
        .disposed(by: disposeBag)

        scheduler.start()

        XCTAssertEqual(
            elementsObs.events, [
                .next(0, []),
                .next(0, (1...5).map { $0 }),
                .next(1, (1...5).map { $0 }),
                .next(1, (1...10).map { $0 }),
                .next(2, (1...10).map { $0 }),
                .next(2, (1...15).map { $0 }),
                .next(3, []),
                .next(3, (1...5).map { $0 })
            ]
        )
    }

    func testDependency() {

        let elementsObs = scheduler.createObserver([Int].self)

        let data = [
            "page1" : [1, 2, 3, 4, 5],
            "page3": [6, 7, 8, 9, 10]
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
        .subscribe(elementsObs)
        .disposed(by: disposeBag)

        scheduler.start()

        XCTAssertEqual(
            elementsObs.events, [
                .next(1, []),
                .next(1, (1...5).map { $0 }),
                .next(2, (1...5).map { $0 }),
                .next(2, (1...5).map { $0 }),
                .next(3, []),
                .next(3, (6...10).map { $0 })
            ]
        )
    }

    func testDependencyRequestCanceled() {

        let elementsObs = scheduler.createObserver([Int].self)

        let data = [
            "page1" : (1...5).map { $0 },
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
        .subscribe(elementsObs)
        .disposed(by: disposeBag)

        scheduler.start()

        XCTAssertEqual(
            elementsObs.events, [
                .next(1, []),
                .next(2, []),
                .next(4, (6...10).map { $0 })
            ]
        )
    }

    func testSimplePaginationUsingDriver() {
        SharingScheduler.mock(scheduler: scheduler, action: _testSimplePaginationUsingDriver)
    }

    func _testSimplePaginationUsingDriver() {

        let elementsObs = scheduler.createObserver([Int].self)

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
        .drive(elementsObs)
        .disposed(by: disposeBag)

        scheduler.start()

        XCTAssertEqual(
            elementsObs.events, [
                .next(0, []),
                .next(0, (1...5).map { $0 }),
                .next(1, (1...5).map { $0 }),
                .next(1, (1...10).map { $0 }),
                .next(2, (1...10).map { $0 }),
                .next(2, (1...15).map { $0 }),
                .next(3, []),
                .next(3, (1...5).map { $0 }),
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
