//
//  UniversalSearchResultsView.swift
//  Planetary
//
//  Created by Matthew Lorentz on 6/28/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import UIKit
import Combine

class UniversalSearchResultsView: UIView {
    
    @Published var searchQuery: String = ""
    @Published private var searchResults = [KeyValue]()
    private var cancellables = [AnyCancellable]()
    
    init() {
        super.init(frame: CGRect.zero)
        setUp()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
    }
    
    required init?(coder: NSCoder) {
        nil
    }
    
    private func setUp() {
        Layout.fill(view: self, with: emptySearchView)
        bindSearchResultsToSearchQuery()
    }
    
    private lazy var emptySearchView: UIView = {
        let view = UIView()
         
        let imageView = UIImageView(image: UIImage(imageLiteralResourceName: "icon-planetary"))
        Layout.centerHorizontally(imageView, in: view)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.topAnchor, constant: 50)
        ])

        let titleLabel = UILabel.forAutoLayout()
        titleLabel.numberOfLines = 0
        titleLabel.font = UIFont.systemFont(ofSize: 25, weight: .medium)
        titleLabel.text = "Search"
        titleLabel.textColor = UIColor.text.default
        titleLabel.textAlignment = .center
        Layout.centerHorizontally(titleLabel, in: view)
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 20)
        ])

        let detailLabel = UILabel.forAutoLayout()
        detailLabel.numberOfLines = 0
        detailLabel.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        detailLabel.text = "Not seeing what you are looking for? blah blah"
        detailLabel.textColor = UIColor.text.default
        detailLabel.textAlignment = .center
        view.addSubview(detailLabel)
        NSLayoutConstraint.activate([
            detailLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            detailLabel.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 60),
            detailLabel.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -60)
        ])

        return view
    }()
    
    private func bindSearchResultsToSearchQuery() {
        $searchQuery
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .removeDuplicates()
            .filter { searchQuery in
                !searchQuery.isEmpty
            }
            .flatMap { searchQuery in
                self.fetchSearchResults(for: searchQuery)
            }
            .assign(to: \.searchResults, on: self)
            .store(in: &cancellables)
            
        $searchQuery
            .sink { [weak self] searchQuery in
                if searchQuery.isEmpty {
                    self?.searchResults = []
                }
            }
            .store(in: &cancellables)
        
        $searchResults
            .sink { newResults in
                self.display(searchResults: newResults)
            }
            .store(in: &cancellables)
    }
    
    private func fetchSearchResults(for query: String) -> AnyPublisher<[KeyValue], Never> {
        return Just([]).eraseToAnyPublisher()
    }
    
    private func display(searchResults: [KeyValue]) {
        if searchResults.isEmpty {
            subviews.forEach { $0.removeFromSuperview() }
            Layout.fill(view: self, with: self.emptySearchView)
        } else {
            subviews.forEach { $0.removeFromSuperview() }
            Layout.fill(view: self, with: self.emptySearchView)
        }
    }
}
