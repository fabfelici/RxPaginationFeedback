# RxPaginationFeedback
![pod](https://img.shields.io/cocoapods/v/RxPaginationFeedback.svg) [![Swift Package Manager compatible](https://img.shields.io/badge/Swift%20Package%20Manager-compatible-brightgreen.svg)](https://github.com/apple/swift-package-manager) [![Build Status](https://travis-ci.com/fabfelici/RxPaginationFeedback.svg?branch=master)](https://travis-ci.com/fabfelici/RxPaginationFeedback) [![codecov](https://codecov.io/gh/fabfelici/RxPaginationFeedback/branch/master/graph/badge.svg)](https://codecov.io/gh/fabfelici/RxPaginationFeedback)

Generic RxSwift operator to easily interact with paginated APIs. Based on [RxFeedback](https://github.com/NoTests/RxFeedback.swift).

## Design

![](Images/state_diagram.png)

```swift
public typealias PageProvider<PageDependency, Element> = (PageDependency) -> Observable<Page<PageDependency, Element>>

public static func paginationSystem<PageDependency: Equatable, Element>(
    scheduler: ImmediateSchedulerType,
    initialDependency: PageDependency,
    loadNext: Observable<Void>,
    pageProvider: @escaping PageProvider<PageDependency, Element>
) -> Observable<[Element]> {
```

## Features
* Simple state machine to represent pagination use cases.
* Reusable pagination logic. No need to duplicate state across different screens with paginated apis.
* Observe result to react to changes on the list of elements.

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

let elements = Driver.paginationSystem(
    initialDependency: 0,
    loadNext: loadNext
) { dependency -> Observable<PageResponse<Int, User>> in

    let page = ((dependency / 3) % 4) + 1
    let urlRequest = URLRequest(url: URL(string: "https://reqres.in/api/users?page=\(page)")!)

    return URLSession.shared.rx.data(request: urlRequest)
        .compactMap {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return (try? decoder.decode(ReqresResponse.self, from: $0).data)
                .map {
                    Page(nextDependency: dependency + $0.count, elements: $0)
                }
        }
}

elements
    .drive(tableView.rx.items(cellIdentifier: "Cell", cellType: UITableViewCell.self)) { index, item, cell in
        cell.textLabel?.text = "\(item.firstName) - \(item.lastName)"
    }
    .disposed(by: disposeBag)
```

[More examples](https://github.com/fabfelici/RxPaginationFeedback/blob/master/Examples/Examples)

<img src="Images/examples.gif" width="350"/>