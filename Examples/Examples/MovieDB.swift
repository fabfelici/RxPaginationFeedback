//
//  MovieDB.swift
//  Examples
//
//  Created by Felici, Fabio on 09/07/2019.
//  Copyright © 2019 Fabio Felici. All rights reserved.
//

import RxSwift
import RxPaginationFeedback

struct MovieDependency: Hashable {
    let page: Int
    let totalPages: Int

    static let initial = MovieDependency(page: 1, totalPages: Int.max)
}

struct MovieResponse: Codable {
    let page: Int
    let totalPages: Int
    let results: [Movie]
}

struct Movie: Codable {
    let overview: String
    let title: String
}

struct MovieDB: PaginatedAPI {

    let label = "MovieDB"
    let shouldDisplaySearchBar = false
    let shouldDisplayTextInput = false

    static let apiKey = "30bdc215a82672289a3fb39320c3e593"

    func elements(
        loadNext: Observable<Void>,
        query: Observable<String>,
        refresh: Observable<Void>,
        numberInput: Observable<String>
    ) -> Observable<(Bool, [PaginationResult], Error?)> {
        return Observable.paginationSystem(
            scheduler: SerialDispatchQueueScheduler(qos: .userInteractive),
            dependencies: refresh
                .map { MovieDependency.initial }
                .startWith(MovieDependency.initial),
            loadNext: loadNext
        ) { dependency -> Observable<Page<MovieDependency, Movie>> in
            guard dependency.page <= dependency.totalPages else {
                return .just(.init(nextDependency: nil, elements: []))
            }

            let request = URLRequest(url: URL(string: "https://api.themoviedb.org/3/discover/movie?api_key=\(MovieDB.apiKey)&sort_by=popularity.desc&page=\(dependency.page)")!)

            return URLSession.shared.rx.data(request: request)
                .compactMap { data in
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase
                    return (try? decoder.decode(MovieResponse.self, from: data))
                        .map {
                            Page(
                                nextDependency: .init(
                                    page: dependency.page + 1,
                                    totalPages: $0.totalPages
                                ),
                                elements: $0.results
                            )
                        }
                }
        }
        .map {
            ($0.isLoading, $0.elements.map {
                .init(title: $0.title, subtitle: $0.overview)
            }, $0.error)
        }
    }
}

