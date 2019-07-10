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
}

struct User: Decodable {
    let firstName: String
    let lastName: String
}

struct ReqresDependency: Hashable {
    let offset: Int
    let limit: Int
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
    ) -> Observable<(Bool, [PaginationResult], Error?)> {
        return Observable.paginationSystem(
            scheduler: SerialDispatchQueueScheduler(qos: .userInteractive),
            userEvents: Observable.merge(
                loadNext.map { .loadNext },
                Observable.merge(
                    numberInput,
                    refresh.withLatestFrom(numberInput)
                )
                .compactMap { Int($0) }
                .map { .dependency(.init(offset: 0, limit: $0)) }
            )
        ) { dependency -> Observable<PageResponse<ReqresDependency, User>> in
            if dependency.offset > dependency.limit {
                return .just(.init(dependency: nil, elements: []))
            }

            let offsetModulo = ((dependency.offset / 3) % 4) + 1
            let urlRequest = URLRequest(url: URL(string: "https://reqres.in/api/users?page=\(offsetModulo)")!)

            return URLSession.shared.rx.data(request: urlRequest)
                .compactMap {
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase
                    return (try? decoder.decode(ReqresResponse.self, from: $0).data).map {
                        let newOffset = dependency.offset + $0.count
                        return PageResponse(
                            dependency: .init(
                                offset: newOffset,
                                limit: dependency.limit
                            )
                        , elements: $0)
                    }
                }
        }
        .map {
            ($0.isLoading, $0.elements.map {
                PaginationResult(title: $0.firstName, subtitle: $0.lastName)
            }, $0.error)
        }
    }
}

