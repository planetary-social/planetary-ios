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

class DirectoryViewController: ContentViewController, AboutTableViewDelegate {

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
    
    private var communityPubs = Environment.Communities.stars
    private var communityPubIdentities = Set(Environment.Communities.stars.map { $0.feed })

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
        controller.obscuresBackgroundDuringPresentation = false
        controller.hidesNavigationBarDuringPresentation = false
        return controller
    }()

    // for a bug fix — see note in Search extension below
    private var searchEditBeginDate = Date()

    init() {
        super.init(scrollable: false, title: .yourNetwork)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        Layout.fill(view: self.view, with: self.tableView)
        self.navigationItem.searchController = self.searchController

        self.definesPresentationContext = true
        self.extendedLayoutIncludesOpaqueBars = false


        //AppController.shared.showProgress()
        self.load {
            AppController.shared.hideProgress()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        CrashReporting.shared.record("Did Show Directory")
        Analytics.shared.trackDidShowScreen(screenName: "directory")
    }

    private func load(completion: @escaping () -> Void) {
        Bots.current.abouts() {
            [weak self] abouts, error in
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
        if self.searchFilter.isEmpty {
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
        }
    }

    @objc func refreshControlValueChanged(control: UIRefreshControl) {
        control.beginRefreshing()
        self.load {
            control.endRefreshing()
        }
    }


    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension DirectoryViewController: UISearchResultsUpdating, UISearchBarDelegate {

    func updateSearchResults(for searchController: UISearchController) {
        Analytics.shared.trackDidTapSearchbar(searchBarName: "directory")
        self.searchFilter = searchController.searchBar.text ?? ""
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
        searchFilter.isEmpty ? 2 : 1
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 && searchFilter.isEmpty {
            return Text.pubServers.text
        } else {
            return Text.usersInYourNetwork.text
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 && searchFilter.isEmpty {
            return Environment.Communities.stars.count
        } else {
            return self.people.count
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 && searchFilter.isEmpty {
            let cell = (tableView.dequeueReusableCell(withIdentifier: CommunityTableViewCell.className) as? CommunityTableViewCell) ?? CommunityTableViewCell()
            let star = communityPubs[indexPath.row]
            if let about = self.allPeople.first(where: { $0.identity == star.feed }) {
                cell.communityView.update(with: star, about: about)
            } else {
                cell.communityView.update(with: star, about: nil)
            }
            return cell
        } else {
            let about = self.people[indexPath.row]
            let isCommunity = communityPubIdentities.contains(about.identity)
            if isCommunity {
                let cell = (tableView.dequeueReusableCell(withIdentifier: CommunityTableViewCell.className) as? CommunityTableViewCell) ?? CommunityTableViewCell()
                if let star = communityPubs.first(where: { $0.feed == about.identity }) {
                    cell.communityView.update(with: star, about: about)
                }
                return cell
            } else {
                let cell = (tableView.dequeueReusableCell(withIdentifier: AboutTableViewCell.className) as? AboutTableViewCell) ?? AboutTableViewCell()
                let about = self.people[indexPath.row]
                cell.aboutView.update(with: about.identity, about: about)
                return cell
            }
        }
    }
}

extension DirectoryViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 0 && searchFilter.isEmpty {
            let star = Environment.Communities.stars[indexPath.row]
            let controller = AboutViewController(with: star.feed)
            self.navigationController?.pushViewController(controller, animated: true)
        } else {
            let about = self.people[indexPath.row]
            let controller = AboutViewController(with: about)
            self.navigationController?.pushViewController(controller, animated: true)
        }
        
    }
}
