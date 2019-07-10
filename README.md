# RxPaginationFeedback
![pod](https://img.shields.io/cocoapods/v/RxPaginationFeedback.svg) [![Swift Package Manager compatible](https://img.shields.io/badge/Swift%20Package%20Manager-compatible-brightgreen.svg)](https://github.com/apple/swift-package-manager)

Generic RxSwift operator to easily interact with paginated APIs. Based on [RxFeedback](https://github.com/NoTests/RxFeedback.swift).

## Design

![](Images/state_diagram.png)

```swift
public typealias PageProvider<PageDependency, Element> = (PageDependency) -> Observable<PageResponse<PageDependency, Element>>

public static func paginationSystem<PageDependency: Hashable, Element>(
    scheduler: ImmediateSchedulerType,
    pageProvider: @escaping PageProvider<PageDependency, Element>,
    userEvents: Observable<PaginationState<PageDependency, Element>.UserEvent>
) -> Observable<PaginationState<PageDependency, Element>>
```

## Features
* Simple state machine to represent pagination use cases.
* Reusable pagination logic. No need to duplicate state across different screens with paginated apis.
* Observe `PaginationState` to react to:
    * loading page events
    * latest api error
    * changes on the list of elements

# Examples

## Simple [Reqres](https://reqres.in/) example

```swift
struct ReqresResponse: Decodable {
    let data: [User]
}

struct User: Decodable {
    let firstName: String
    let lastName: String
}

let reqresState = Observable.paginationSystem(
    scheduler: SerialDispatchQueueScheduler(qos: .userInteractive),
    pageProvider: { dependency -> Observable<PageResponse<Int, User>> in

        let offsetModulo = ((dependency / 3) % 4) + 1
        let urlRequest = URLRequest(url: URL(string: "https://reqres.in/api/users?page=\(offsetModulo)")!)

        return URLSession.shared.rx.data(request: urlRequest)
            .compactMap {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                return (try? decoder.decode(ReqresResponse.self, from: $0).data)
                    .map {
                        let newOffset = dependency + $0.count
                        return PageResponse(dependency: newOffset, elements: $0)
                    }
            }
    },
    userEvents: loadNext.map { .loadNext }
        .startWith(.dependency(0))
)
```

[More examples](https://github.com/fabfelici/RxPaginationFeedback/blob/master/Examples/Examples)

<img src="Images/examples.gif" width="350"/>