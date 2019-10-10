//
//  PaginationSystemViewController.swift
//  Examples
//
//  Created by Felici, Fabio on 05/07/2019.
//  Copyright © 2019 Fabio Felici. All rights reserved.
//

import UIKit
import RxCocoa
import RxSwift
import RxPaginationFeedback

final class PaginationFeedbackViewController: UIViewController {

    private lazy var statusLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        return label
    }()

    private lazy var apiSelector: UISegmentedControl = {
        UISegmentedControl()
    }()

    private lazy var searchBar: UISearchBar = {
        UISearchBar()
    }()

    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.register(SimpleCell.self, forCellReuseIdentifier: "SimpleCell")
        return tableView
    }()

    private lazy var refreshControl: UIRefreshControl = {
        UIRefreshControl()
    }()

    private lazy var textField: UITextField = {
        UITextField()
    }()

    private let disposeBag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()
        edgesForExtendedLayout = []
        layoutView()
        setupPaginationSystem()
    }

    private func layoutView() {
        navigationController?.navigationBar.isTranslucent = false
        navigationController?.navigationBar.backgroundColor = .white
        view.backgroundColor = .white
        tableView.refreshControl = refreshControl
        searchBar.placeholder = "Search Repositories"
        let textFieldWrapper = UIView()
        textField.placeholder = "Pages Limit"
        textField.translatesAutoresizingMaskIntoConstraints = false
        textFieldWrapper.addSubview(textField)
        textField.backgroundColor = .groupTableViewBackground
        let stackView = UIStackView(arrangedSubviews: [
            statusLabel,
            apiSelector,
            textFieldWrapper,
            searchBar,
            tableView
        ])
        stackView.isLayoutMarginsRelativeArrangement = true
        stackView.spacing = 20
        stackView.layoutMargins = .init(top: 20, left: 0, bottom: 0, right: 0)
        stackView.axis = .vertical
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)
        NSLayoutConstraint.activate([
            apiSelector.heightAnchor.constraint(equalToConstant: 40),
            searchBar.heightAnchor.constraint(equalToConstant: 50),
            stackView.topAnchor.constraint(equalTo: view.topAnchor),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            textField.heightAnchor.constraint(equalToConstant: 40),
            textField.topAnchor.constraint(equalTo: textFieldWrapper.topAnchor),
            textField.bottomAnchor.constraint(equalTo: textFieldWrapper.bottomAnchor, constant: -15),
            textField.leadingAnchor.constraint(equalTo: textFieldWrapper.leadingAnchor, constant: 15),
            textField.trailingAnchor.constraint(equalTo: textFieldWrapper.trailingAnchor, constant: -15)
        ])
    }

    private func setupPaginationSystem() {
        let gitHub = Github()
        let apis: [PaginatedAPI] = [gitHub, Reqres(), MovieDB()]

        apis.enumerated().forEach {
            apiSelector.insertSegment(withTitle: $0.element.label, at: $0.offset, animated: false)
        }
        apiSelector.selectedSegmentIndex = 0

        apiSelector.rx.controlEvent(.valueChanged)
            .subscribe(onNext: { [weak self] in
                self?.searchBar.text = nil
            })
            .disposed(by: disposeBag)

        let selectedApi = apiSelector.rx.controlEvent(.valueChanged)
            .map { self.apiSelector.selectedSegmentIndex }
            .map { apis[$0] }
            .startWith(gitHub)

        let refreshEvent = refreshControl.rx.controlEvent(.valueChanged)
        let searchBarEvent = searchBar.rx.text.orEmpty
            .throttle(.milliseconds(500), scheduler: MainScheduler.asyncInstance)
        let loadNext = tableView.rx.nearBottom.asObservable().skip(1)
        let numberInput = textField.rx.text.orEmpty
            .startWith("10")
            .scan(("", ""), accumulator: {
                CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: $1)) ? ($0.1, $1) : $0
            })
            .map { $0.1 }
            .share(replay: 1)

        numberInput
            .bind(to: textField.rx.text)
            .disposed(by: disposeBag)

        let state = selectedApi
            .flatMapLatest {
                $0.elements(
                    loadNext: loadNext,
                    query: searchBarEvent,
                    refresh: refreshEvent.asObservable(),
                    numberInput: numberInput.distinctUntilChanged()
                )
            }
            .asDriver(onErrorJustReturn: .init(isLoading: false, error: nil, elements: []))

        selectedApi
            .map { !$0.shouldDisplaySearchBar }
            .bind(to: searchBar.rx.isHidden)
            .disposed(by: disposeBag)

        selectedApi.map { !$0.shouldDisplayTextInput }
            .bind(to: textField.superview!.rx.isHidden)
            .disposed(by: disposeBag)

        state
            .map { $0.elements.isEmpty && $0.isLoading }
            .distinctUntilChanged()
            .drive(refreshControl.rx.isRefreshing)
            .disposed(by: disposeBag)

        state
            .map {
                $0.error.map { $0.localizedDescription } ?? "\($0.isLoading ? "Loading" : "Loaded" )\nItems: \($0.elements.count)"
            }
            .drive(statusLabel.rx.text)
            .disposed(by: disposeBag)

        state.map { $0.elements }
            .distinctUntilChanged()
            .drive(tableView.rx.items(cellIdentifier: "SimpleCell", cellType: SimpleCell.self)) { index, item, cell in
                cell.textLabel?.text = "\(item.title) - \(index)"
                cell.detailTextLabel?.text = item.subtitle
            }
            .disposed(by: disposeBag)

        selectedApi
            .map { $0.label }
            .bind(to: rx.title)
            .disposed(by: disposeBag)
    }
}

protocol PaginatedAPI {
    func elements(
        loadNext: Observable<Void>,
        query: Observable<String>,
        refresh: Observable<Void>,
        numberInput: Observable<String>
    ) -> Observable<PaginationState>

    var label: String { get }
    var shouldDisplaySearchBar: Bool { get }
    var shouldDisplayTextInput: Bool { get }
}

struct PaginationState {
    let isLoading: Bool
    let error: Error?
    let elements: [PaginationResult]
}

struct PaginationResult: Equatable {
    let title: String
    let subtitle: String
}

extension Reactive where Base: UITableView {

    var nearBottom: Signal<()> {
        func isNearBottomEdge(tableView: UITableView, edgeOffset: CGFloat = 20.0) -> Bool {
            return tableView.contentOffset.y + tableView.frame.size.height + edgeOffset > tableView.contentSize.height
        }

        return self.contentOffset.asSignal(onErrorSignalWith: .empty())
            .flatMap { _ in
                return isNearBottomEdge(tableView: self.base)
                    ? .just(())
                    : .empty()
            }
    }
}

final class SimpleCell: UITableViewCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError()
    }
}
