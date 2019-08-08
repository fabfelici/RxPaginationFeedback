//
//  Github.swift
//  Examples
//
//  Created by Felici, Fabio on 08/07/2019.
//  Copyright © 2019 Fabio Felici. All rights reserved.
//

import RxSwift
import RxPaginationFeedback
import RxCocoa

struct GHResponse: Decodable {
    let items: [GHRepo]
}

struct GHRepo: Decodable {
    let name: String
    let url: URL
}

struct Github: PaginatedAPI {

    let label = "Github"
    let shouldDisplaySearchBar = true
    let shouldDisplayTextInput = false

    func elements(
        loadNext: Observable<Void>,
        query: Observable<String>,
        refresh: Observable<Void>,
        numberInput: Observable<String>
    ) -> Observable<[PaginationResult]> {
        return Observable.merge(
            refresh.withLatestFrom(query),
            query
        )
        .map { query -> URL? in
            let url = !query.isEmpty ? query.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)
                .map { "https://api.github.com/search/repositories?q=\($0)" } : nil
            return url.flatMap { URL(string: $0) }
        }
        .flatMapLatest { url -> Observable<[GHRepo]> in

            guard let url = url else { return Observable.just([]) }

            return Observable.paginationSystem(
                scheduler: SerialDispatchQueueScheduler(qos: .userInteractive),
                initialDependency: url,
                loadNext: loadNext
            ) { dependency -> Observable<Page<URL, GHRepo>> in
                URLSession.shared.rx.response(request: URLRequest(url: dependency))
                    .compactMap { args in
                        let (httpResponse, data) = args
                        guard 200 ..< 300 ~= httpResponse.statusCode else {
                            throw RxCocoaURLError.httpRequestFailed(response: httpResponse, data: data)
                        }

                        let decoder = JSONDecoder()
                        let response = try? decoder.decode(GHResponse.self, from: data)
                        let linksHeader = httpResponse.allHeaderFields["Link"] as? String
                        let links = try linksHeader.map(parseLinks) ?? [:]

                        return response
                            .map { Page(nextDependency: links["next"].flatMap { URL(string: $0) }, elements: $0.items) }
                    }
            }
        }
        .map {
            $0.map { .init(title: $0.name, subtitle: $0.url.absoluteString ) }
        }
    }
}

fileprivate func parseLinks(_ links: String) throws -> [String: String] {
    let _matches = try matches(for: "<([^\\>]+)>; rel=\"([^\"]*)\"", in: links)
    return .init(uniqueKeysWithValues:
        zip(
            _matches.enumerated().filter { $0.offset % 2 != 0 }.map { $0.element },
            _matches.enumerated().filter { $0.offset % 2 == 0 }.map { $0.element }
        )
    )
}

fileprivate func matches(for regex: String, in text: String) throws -> [String] {
    let regex = try NSRegularExpression(pattern: regex)
    let results = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
    return results.flatMap { match in
        (1 ..< match.numberOfRanges).compactMap {
            Range(match.range(at: $0), in: text).map { String(text[$0]) }
        }
    }
}
