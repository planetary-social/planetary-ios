//
//  UniversalSearchResultsView.swift
//  Planetary
//
//  Created by Matthew Lorentz on 6/28/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import UIKit
import Combine
import Logger
import CrashReporting
import SwiftUI

protocol UniversalSearchDelegate: AnyObject {
    func present(_ controller: UIViewController)
}

// MARK: - Internal Models

/// A model for all the different types of results that can be displayed.
fileprivate struct SearchResults {
    enum ResultData {
        case universal(people: [About], posts: [Message])
        case feedID(Either<About, FeedIdentifier>)
        case messageID(Either<Message, MessageIdentifier>)
        case loading
        case none
    }
    
    var data: ResultData
    var query: String
    
    /// The table view sections that should be displayed for these results.
    var activeSections: [Section] {
        switch data {
        case .universal:
            return [.network, .posts]
        case .feedID(let result):
            switch result {
            case .left:
                return [.network]
            case .right:
                return [.users]
            }
        case .messageID:
            return [.posts]
        case .loading, .none:
            return []
        }
    }
    
    var posts: [Message]? {
        switch data {
        case .universal(_, let posts):
            return posts
        case .messageID(let result):
            switch result {
            case .left(let message):
                return [message]
            case .right:
                return nil
            }
        default:
            return nil
        }
    }
    
    var inNetworkPeople: [About]? {
        switch data {
        case .universal(let people, _):
            return people
        case .feedID(let result):
            switch result {
            case .left(let about):
                return [about]
            case .right:
                return nil
            }
        default:
            return nil
        }
    }
    
    var user: FeedIdentifier? {
        switch data {
        case .feedID(let result):
            switch result {
            case .left:
                return nil
            case .right(let identifier):
                return identifier
            }
        default:
            return nil
        }
    }
    
    var postCount: Int {
        posts?.count ?? 0
    }
    
    var inNetworkPeopleCount: Int {
        inNetworkPeople?.count ?? 0
    }
}

/// A model for the various table view sections
fileprivate enum Section: Int, CaseIterable {
    case users, posts, network
}

// MARK: - View

/// This view computes and displays results for "universal search", meaning search of posts, users, and message IDs.
/// It does not contain a search bar and is intended to be embedded inside a view controller that adheres to
/// `UniversalSearchDelegate`. This view controller manages the search bar and keyboard and informs the view when
/// the query changes by setting `searchQuery`.
///
/// This implementation was hastily copied from the `DirectoryViewController` so the code quality isn't great.
class UniversalSearchResultsView: UIView, UITableViewDelegate, UITableViewDataSource {
    
    // MARK: - Public Properties
    
    /// A delegate that will be used to manage scene changes like presenting new view controllers.
    weak var delegate: UniversalSearchDelegate?
    
    /// The text the user is searching for.
    @Published var searchQuery: String = ""
    
    // MARK: - Private Properties
    
    private let communityPubs = AppConfiguration.current?.communityPubs ?? []
    private lazy var communityPubIdentities = Set(communityPubs.map { $0.feed })
    
    @Published private var searchResults = SearchResults(data: .none, query: "")
    private var cancellables = [AnyCancellable]()
    private let searchQueue = DispatchQueue(label: "searchQueue", qos: .userInitiated)
    private var latestQuery = ""
    
    // MARK: - Views
    
    private lazy var tableView: UITableView = {
        let view = UITableView.forVerse(style: .grouped)
        view.dataSource = self
        view.delegate = self
        view.separatorColor = UIColor.separator.middle
        view.rowHeight = UITableView.automaticDimension
        view.estimatedRowHeight = 300
        view.addSeparatorAsHeaderView()
        return view
    }()
    
    private lazy var emptySearchView: UIView = {
        let view = UIView()
         
        let titleLabel = UILabel.forAutoLayout()
        titleLabel.numberOfLines = 0
        titleLabel.font = UIFont.preferredFont(forTextStyle: .title2)
        titleLabel.text = Localized.noResultsFound.text
        titleLabel.textColor = UIColor.text.default
        titleLabel.textAlignment = .center
        Layout.center(titleLabel, atTopOf: view, inset: 100)

        let detailLabel = UILabel.forAutoLayout()
        detailLabel.numberOfLines = 0
        detailLabel.font = UIFont.preferredFont(forTextStyle: .body)
        detailLabel.text = Localized.noResultsHelp.text
        detailLabel.textColor = UIColor.text.detail
        detailLabel.textAlignment = .left
        view.addSubview(detailLabel)
        let leftConstraint = detailLabel.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 40)
        leftConstraint.priority = .defaultHigh
        let rightConstraint = detailLabel.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -40)
        rightConstraint.priority = .defaultHigh
        NSLayoutConstraint.activate([
            detailLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            leftConstraint,
            rightConstraint,
            detailLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            detailLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 350)
        ])

        return view
    }()
    
    private lazy var loadingAnimation: PeerConnectionAnimation = {
        let view = PeerConnectionAnimation(color: .networkAnimation)
        view.setDotCount(inside: false, count: 1, animated: false)
        view.setDotCount(inside: true, count: 2, animated: false)
        return view
    }()
    
    private lazy var loadingLabel: UILabel = {
        let view = UILabel.forAutoLayout()
        view.textAlignment = .center
        view.numberOfLines = 2
        view.text = Localized.searchingLocally.text
        view.textColor = UIColor.tint.default
        return view
    }()
    
    // MARK: - Setup
    
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
        // empty view
        addSubview(emptySearchView)
        Layout.fill(view: self, with: emptySearchView)
        
        // results table view
        addSubview(tableView)
        Layout.fill(view: self, with: tableView)
        tableView.isHidden = true
        
        // loading view
        addSubview(loadingLabel)
        addSubview(loadingAnimation)
        Layout.center(self.loadingLabel, in: self)
        Layout.centerHorizontally(self.loadingAnimation, in: self)
        self.loadingAnimation.constrainSize(to: self.loadingAnimation.totalDiameter)
        self.loadingAnimation.pinBottom(toTopOf: self.loadingLabel, constant: -20, activate: true)
        loadingLabel.isHidden = true
        loadingAnimation.isHidden = true
        
        bindSearchResultsToSearchQuery()
    }
    
    private func bindSearchResultsToSearchQuery() {
        $searchQuery
            .removeDuplicates()
            .sink { searchQuery in
                self.latestQuery = searchQuery
                // side effect to show loading indicator
                self.display(searchResults: SearchResults(data: .loading, query: searchQuery))
            }
            .store(in: &cancellables)
        
        $searchQuery
            .removeDuplicates()
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .receive(on: searchQueue)
            .asyncFlatMap { searchQuery -> SearchResults in
                await self.fetchSearchResults(for: searchQuery)
            }
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { searchResults in
                self.searchResults = searchResults
                self.display(searchResults: searchResults)
            })
            .store(in: &cancellables)
    }
    
    // MARK: - Loading Search Results
    
    private func fetchSearchResults(for query: String) async -> SearchResults {
        guard !query.isEmpty else {
            return SearchResults(data: .none, query: query)
        }
        
        let normalizedQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let identifier: Identifier = query
        let isFeedIdentifier = identifier.isValidIdentifier && identifier.sigil == .feed
        let isMessageIdentifier = identifier.isValidIdentifier && identifier.sigil == .message
        
        if isFeedIdentifier {
            return SearchResults(data: .feedID(await loadPerson(with: identifier)), query: query)
        } else if isMessageIdentifier {
            return SearchResults(data: .messageID(await loadMessage(with: identifier)), query: query)
        } else {
            async let people = loadPeople(matching: normalizedQuery)
            async let posts = loadPosts(matching: normalizedQuery)
            return SearchResults(data: .universal(people: await people, posts: await posts), query: query)
        }
    }
    
    func loadPeople(matching filter: String) async -> [About] {
        do {
            return try await Bots.current.abouts(matching: filter)
        } catch {
            Log.optional(error)
            return []
        }
    }
    
    func loadPosts(matching filter: String) async -> [Message] {
        do {
            return try await Bots.current.posts(matching: filter)
        } catch {
            Log.optional(error)
            return []
        }
    }
    
    /// Loads the message with the given id from the database and displays it if it's still valid.
    func loadMessage(with msgID: MessageIdentifier) async -> Either<Message, MessageIdentifier> {
        var result: Either<Message, MessageIdentifier>
        do {
            result = .left(try Bots.current.post(from: msgID))
        } catch {
            result = .right(msgID)
            Log.optional(error)
        }
        return result
    }
    
    func loadPerson(with feedIdentifier: FeedIdentifier) async -> Either<About, FeedIdentifier> {
        var result: Either<About, FeedIdentifier>
        do {
            let about = try await Bots.current.about(identity: feedIdentifier)
            if let about = about {
                result = .left(about)
            } else {
                result = .right(feedIdentifier)
            }
        } catch {
            result = .right(feedIdentifier)
            Log.optional(error)
        }
        return result
    }
    
    // MARK: - View Manipulation
    
    private func display(searchResults: SearchResults) {
        // Discard results if the user has already searched for another query.
        guard searchResults.query == latestQuery else {
            return
        }
        
        // Hide all views. Then we will unhide the appropriate ones.
        tableView.isHidden = true
        emptySearchView.isHidden = true
        loadingLabel.isHidden = true
        loadingAnimation.isHidden = true
        
        switch searchResults.data {
        case .universal:
            if searchResults.posts?.isEmpty == true &&
                searchResults.inNetworkPeople?.isEmpty == true {
                emptySearchView.isHidden = false
            } else {
                tableView.isHidden = false
            }
        case .feedID, .messageID:
            tableView.isHidden = false
        case .loading:
            loadingLabel.isHidden = false
            loadingAnimation.isHidden = false
        case .none:
            emptySearchView.isHidden = false
        }
        
        tableView.reloadData()
    }
    
    // MARK: - Table View
    
    func numberOfSections(in tableView: UITableView) -> Int {
        searchResults.activeSections.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard !searchResults.activeSections.isEmpty else {
            return nil
        }
        
        let section = searchResults.activeSections[section]
        
        switch section {
        case .users:
            return Localized.users.text
        case .posts:
            return Localized.posts.text
        case .network:
            return Localized.usersInYourNetwork.text
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let section = searchResults.activeSections[section]
        
        switch section {
        case .users:
            return searchResults.user != nil ? 1 : 0
        case .posts:
            return searchResults.postCount
        case .network:
            return searchResults.inNetworkPeopleCount
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let section = searchResults.activeSections[indexPath.section]
        
        switch section {
        case .users:
            guard let feedIdentifier = searchResults.user else {
                return UITableViewCell()
            }
            
            let cell = (
                tableView.dequeueReusableCell(withIdentifier: AboutTableViewCell.className) as? AboutTableViewCell
            ) ?? AboutTableViewCell()
            cell.aboutView.update(with: feedIdentifier, about: nil)
            return cell
        case .posts:
            guard let posts = searchResults.posts else {
                return UITableViewCell()
            }
            let post = posts[indexPath.row]
            let type = post.contentType
            var cell = tableView.dequeueReusableCell(withIdentifier: type.reuseIdentifier) as? MessageTableViewCell
            if cell == nil {
                cell = MessageTableViewCell(for: type, height: 300)
            }
            if let postView = cell?.messageView as? PostCellView {
                postView.truncationLimit = (over: 10, to: 8)
                postView.tapGesture.tap = { [weak self] in
                    guard let self = self else {
                        return
                    }
                    
                    self.tableView(self.tableView, didSelectRowAt: indexPath)
                }
            }
            cell?.update(with: post)
            return cell ?? UITableViewCell()
        case .network:
            guard let inNetworkPeople = searchResults.inNetworkPeople else {
                return UITableViewCell()
            }
            let about = inNetworkPeople[indexPath.row]
            let isCommunity = communityPubIdentities.contains(about.identity)
            if isCommunity {
                let cell = (
                    tableView.dequeueReusableCell(withIdentifier: CommunityTableViewCell.className)
                    as? CommunityTableViewCell
                ) ?? CommunityTableViewCell()
                if let star = communityPubs.first(where: { $0.feed == about.identity }) {
                    cell.communityView.update(with: star, about: about)
                }
                return cell
            } else {
                guard let inNetworkPeople = searchResults.inNetworkPeople else {
                    return UITableViewCell()
                }
                let about = inNetworkPeople[indexPath.row]
                let cell = (
                    tableView.dequeueReusableCell(withIdentifier: AboutTableViewCell.className) as? AboutTableViewCell
                ) ?? AboutTableViewCell()
                cell.aboutView.update(with: about.identity, about: about)
                return cell
            }
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let section = searchResults.activeSections[indexPath.section]
        
        switch section {
        case .users:
            let identity = searchQuery
            let controller = UIHostingController(rootView: IdentityViewBuilder.build(identity: identity))
            delegate?.present(controller)
        case .posts:
            guard let posts = searchResults.posts else {
                return
            }
            let post = posts[indexPath.row]
            let controller = ThreadViewController(with: post, startReplying: false)
            delegate?.present(controller)
        case .network:
            guard let inNetworkPeople = searchResults.inNetworkPeople else {
                return
            }
            let about = inNetworkPeople[indexPath.row]
            let identity = about.identity
            let controller = UIHostingController(rootView: IdentityViewBuilder.build(identity: identity))
            delegate?.present(controller)
        }
    }
}
