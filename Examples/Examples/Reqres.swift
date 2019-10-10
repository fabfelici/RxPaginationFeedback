//
//  Reqres.swift
//  Examples
//
//  Created by Felici, Fabio on 08/07/2019.
//  Copyright © 2019 Fabio Felici. All rights reserved.
//

import RxSwift
import RxPaginationFeedback

struct ReqresResponse: Decodable {
    let data: [User]
    let totalPages: Int
}

struct User: Decodable {
    let firstName: String
    let lastName: String
}

struct ReqresDependency: Equatable {
    let nextPage: Int
    let limit: Int
    let totalPages: Int
}

struct Reqres: PaginatedAPI {

    let label = "Reqres"
    let shouldDisplaySearchBar = false
    let shouldDisplayTextInput = true

    func elements(
        loadNext: Observable<Void>,
        query: Observable<String>,
        refresh: Observable<Void>,
        numberInput: Observable<String>
    ) -> Observable<PaginationState> {
        return Observable.merge(
            numberInput,
            refresh.withLatestFrom(numberInput)
        )
        .map { Int($0) ?? 1 }
        .map { .init(nextPage: 1, limit: $0, totalPages: 10) }
        .flatMapLatest {
            Observable.paginationSystem(
                scheduler: SerialDispatchQueueScheduler(qos: .userInteractive),
                initialDependency: $0,
                loadNext: loadNext
            ) { dependency -> Observable<Page<ReqresDependency, PaginationResult>> in
                if dependency.nextPage > dependency.limit {
                    return .just(.init(nextDependency: nil, elements: []))
                }

                let page = dependency.nextPage % dependency.totalPages + 1
                let urlRequest = URLRequest(url: URL(string: "https://reqres.in/api/users?page=\(page)")!)

                return URLSession.shared.rx.data(request: urlRequest)
                    .compactMap {
                        let decoder = JSONDecoder()
                        decoder.keyDecodingStrategy = .convertFromSnakeCase
                        return (try? decoder.decode(ReqresResponse.self, from: $0)).map {
                            return Page(
                                nextDependency: .init(
                                    nextPage: dependency.nextPage + 1,
                                    limit: dependency.limit,
                                    totalPages: $0.totalPages
                                ),
                                elements: $0.data.map { .init(title: $0.firstName, subtitle: $0.lastName) }
                            )
                        }
                    }
            }
        }
        .map {
            .init(isLoading: $0.isLoading, error: $0.error, elements: $0.elements)
        }
    }
}
