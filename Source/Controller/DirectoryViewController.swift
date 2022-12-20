//
//  DirectoryViewController.swift
//  Planetary
//
//  Created by Zef Houssney on 10/10/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import UIKit
import Logger
import Analytics
import CrashReporting
import SwiftUI

class DirectoryViewController: ContentViewController, AboutTableViewDelegate, HelpDrawerViewControllerHost {
    
    /// A model for the various table view sections
    enum Section: Int, CaseIterable {
        case communityPubs, users, posts, network
    }
    
    /// The default table view sections shown when the user isn't searching.
    static let defaultSections = [Section.communityPubs, Section.network]
    
    /// The list of sections that should appear currently in the table view.
    var activeSections = defaultSections

    // unfiltered collection
    private var allPeople = [About]() {
        didSet {
            applySearchFilter()
        }
    }

    // filtered collection for display
    private var people = [About]() {
        didSet {
            tableView.reloadData()
        }
    }

    // text on which to filter results
    private var searchFilter = "" {
        didSet {
            applySearchFilter()
        }
    }
    
    private let communityPubs = (AppConfiguration.current?.communityPubs ?? []) +
        (AppConfiguration.current?.systemPubs ?? [])
    private lazy var communityPubIdentities = Set(communityPubs.map { $0.feed })
    
    /// A post that was loaded when the user put its ID in the search bar.
    private var searchedPost: Message?
    
    lazy var helpButton: UIBarButtonItem = { HelpDrawerCoordinator.helpBarButton(for: self) }()
    var helpDrawerType: HelpDrawer { .network }

    private lazy var tableView: UITableView = {
        let view = UITableView.forVerse(style: .grouped)
        view.dataSource = self
        view.delegate = self
        view.refreshControl = self.refreshControl
        view.separatorColor = UIColor.separator.middle
        view.addSeparatorAsHeaderView()
        return view
    }()

    private lazy var refreshControl: UIRefreshControl = {
        let control = UIRefreshControl.forAutoLayout()
        control.addTarget(self, action: #selector(refreshControlValueChanged(control:)), for: .valueChanged)
        return control
    }()

    private lazy var searchController: UISearchController = {
        let controller = UISearchController(searchResultsController: nil)
        controller.searchResultsUpdater = self
        controller.searchBar.delegate = self
        controller.searchBar.isTranslucent = false
        controller.searchBar.placeholder = Localized.searchForUsers.text
        controller.obscuresBackgroundDuringPresentation = false
        controller.hidesNavigationBarDuringPresentation = false
        return controller
    }()

    // for a bug fix — see note in Search extension below
    private var searchEditBeginDate = Date()

    init() {
        super.init(scrollable: false, title: .yourNetwork)
        navigationItem.rightBarButtonItems = [helpButton]
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        Layout.fill(view: self.view, with: self.tableView)
        self.navigationItem.searchController = self.searchController

        self.definesPresentationContext = true
        self.extendedLayoutIncludesOpaqueBars = false

        // AppController.shared.showProgress()
        self.load {
            AppController.shared.hideProgress()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        CrashReporting.shared.record("Did Show Directory")
        Analytics.shared.trackDidShowScreen(screenName: "directory")
        HelpDrawerCoordinator.showFirstTimeHelp(for: self)
    }

    private func load(completion: @escaping () -> Void) {
        Bots.current.abouts { [weak self] abouts, error in
            Log.optional(error)
            CrashReporting.shared.reportIfNeeded(error: error)
            self?.allPeople = abouts
            completion()
        }
    }

    func reload() {
        self.tableView.reloadData()
    }

    func applySearchFilter() {
        searchedPost = nil
        
        if self.searchFilter.isEmpty {
            activeSections = Self.defaultSections
            self.people = allPeople.filter { person in
                !self.communityPubIdentities.contains(person.identity)
            }
        } else {
            let filter = searchFilter.lowercased()
            people = allPeople.filter { about in
                let containsName = about.name?.lowercased().contains(filter) ?? false
                let containsIdentity = about.identity.lowercased().contains(filter)
                return containsName || containsIdentity
            }
            
            if !people.isEmpty {
                activeSections = [.network]
            } else {
                let identifier: Identifier = searchFilter
                if identifier.isValidIdentifier && identifier.sigil == .feed {
                    // FeedID
                    activeSections = [.users]
                } else if identifier.isValidIdentifier && identifier.sigil == .message {
                    // Post ID
                    loadAndDisplayMessage(with: identifier)
                } else {
                    activeSections = Self.defaultSections
                }
            }
        }
        
        tableView.reloadData()
    }

    @objc
    func refreshControlValueChanged(control: UIRefreshControl) {
        control.beginRefreshing()
        self.load {
            control.endRefreshing()
        }
    }

    required init?(coder aDecoder: NSCoder) {
        nil
    }
    
    /// Loads the message with the given id from the database and displays it if it's still valid.
    func loadAndDisplayMessage(with msgID: MessageIdentifier) {
        AppController.shared.showProgress(after: 0.3, statusText: Localized.searching.text)
        Task.detached(priority: .high) { [weak self] in
            var result: Either<Message, MessageIdentifier>
            do {
                result = .left(try Bots.current.post(from: msgID))
            } catch {
                result = .right(msgID)
                Log.optional(error)
            }
            
            await self?.displayLoadedSearchResult(result)
            await AppController.shared.hideProgress()
        }
    }
    
    func displayLoadedSearchResult(_ result: Either<Message, MessageIdentifier>) {
        switch result {
        case .left(let message):
            guard searchFilter == message.key else {
                return
            }

            if message.contentType == .post {
                searchedPost = message
            }
            activeSections = [.posts]
            tableView.reloadData()
        case .right(let msgID):
            guard searchFilter == msgID else {
                return
            }
            
            activeSections = [.posts]
            tableView.reloadData()
        }
    }
}

extension DirectoryViewController: UISearchResultsUpdating, UISearchBarDelegate {

    func updateSearchResults(for searchController: UISearchController) {
        Analytics.shared.trackDidTapSearchbar(searchBarName: "directory")
        self.searchFilter = searchController.searchBar.text?.trimmingCharacters(in: .whitespaces) ?? ""
    }

    // These two functions are implemented to avoid a bug where the initial
    // tap of the search bar begins editing, but first responder is immediately resigned
    // I can't figure out why this is happening, but this is a potential solution to avoid the bug.
    // I set a symbolic breakpoint and can't find why resignFirstResponder is being called there.
    //
    // first, when the edit begins, we store the date in self.searchEditBeginDate
    // then, in searchBarShouldEndEditing, we check whether this date was extremely recent
    // if it was too recent to be performed intentionally, we don't allow the field to end editing.
    func searchBarShouldBeginEditing(_ searchBar: UISearchBar) -> Bool {
        self.searchEditBeginDate = Date()
        return true
    }

    func searchBarShouldEndEditing(_ searchBar: UISearchBar) -> Bool {
        let timeSinceStart = Date().timeIntervalSince(self.searchEditBeginDate)
        return timeSinceStart > 0.4
    }
}

extension DirectoryViewController: TopScrollable {
    func scrollToTop() {
        self.tableView.scrollToTop()
    }
}

extension DirectoryViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        activeSections.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let section = activeSections[section]
        
        switch section {
        case .communityPubs:
            return Localized.pubServers.text
        case .users:
            return Localized.users.text
        case .posts:
            return Localized.posts.text
        case .network:
            return Localized.usersInYourNetwork.text
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let section = activeSections[section]
        
        switch section {
        case .communityPubs:
            return searchFilter.isEmpty ? communityPubs.count : 0
        case .users:
            return activeSections.contains(.users) ? 1 : 0
        case .posts:
            return 1
        case .network:
            return people.count
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let section = activeSections[indexPath.section]
        
        switch section {
        case .communityPubs:
            let cell = dequeueExtendedAboutTableViewCell(in: tableView)
            let star = communityPubs[indexPath.row]
            if let about = self.allPeople.first(where: { $0.identity == star.feed }) {
                cell.aboutView.update(with: star.feed, about: about, star: star)
            } else {
                cell.aboutView.update(with: star.feed, about: nil, star: star)
            }
            return cell
        case .users:
            let cell = dequeueExtendedAboutTableViewCell(in: tableView)
            cell.aboutView.update(with: searchFilter, about: nil)
            return cell
        case .posts:
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            
            if let post = searchedPost {
                cell.textLabel?.text = Localized.openPost.text(["postID": post.key])
                cell.textLabel?.textColor = UIColor.tint.default
            } else {
                cell.textLabel?.text = Localized.postNotFound.text
            }
            
            return cell
            
        case .network:
            // Users in Your Network
            let about = self.people[indexPath.row]
            let isCommunity = communityPubIdentities.contains(about.identity)
            if isCommunity {
                let cell = dequeueExtendedAboutTableViewCell(in: tableView)
                if let star = communityPubs.first(where: { $0.feed == about.identity }) {
                    cell.aboutView.update(with: star.feed, about: about, star: star)
                }
                return cell
            } else {
                let cell = dequeueExtendedAboutTableViewCell(in: tableView)
                let about = self.people[indexPath.row]
                cell.aboutView.update(with: about.identity, about: about)
                return cell
            }
        }
    }

    private func dequeueExtendedAboutTableViewCell(in tableView: UITableView) -> ExtendedAboutTableViewCell {
        let dequeuedCell = tableView.dequeueReusableCell(withIdentifier: ExtendedAboutTableViewCell.className)
        if let extendedAboutTableViewCell = dequeuedCell as? ExtendedAboutTableViewCell {
            return extendedAboutTableViewCell
        }
        return ExtendedAboutTableViewCell()
    }
}

extension DirectoryViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let section = activeSections[indexPath.section]
        
        switch section {
        case .communityPubs:
            let star = communityPubs[indexPath.row]
            let view = IdentityViewBuilder().build(identity: star.feed, botRepository: .shared, appController: .shared)
            let controller = UIHostingController(rootView: view)
            self.navigationController?.pushViewController(controller, animated: true)
        case .users:
            let identity = searchFilter
            let view = IdentityViewBuilder().build(identity: identity, botRepository: .shared, appController: .shared)
            let controller = UIHostingController(rootView: view)
            self.navigationController?.pushViewController(controller, animated: true)
        case .posts:
            guard let post = searchedPost else {
                Log.error("DirectoryViewController detected a tap for a nil searchedMessage.")
                return
            }
            
            navigationController?.pushViewController(
                ThreadViewController(with: post, startReplying: false), animated: true
            )
        case .network:
            let identity = self.people[indexPath.row].identity
            let view = IdentityViewBuilder().build(identity: identity, botRepository: .shared, appController: .shared)
            let controller = UIHostingController(rootView: view)
            self.navigationController?.pushViewController(controller, animated: true)
        }
    }
}
