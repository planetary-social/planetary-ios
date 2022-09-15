//
//  ChannelsViewController.swift
//  FBTT
//
//  Created by Christoph on 6/25/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit
import Logger
import Analytics
import CrashReporting

class ChannelsViewController: ContentViewController, HelpDrawerHost {
    
    // unfiltered collection
    private var allChannels = [Hashtag]() {
        didSet {
            applySearchFilter()
        }
    }

    // filtered collection for display
    private var channels = [Hashtag]() {
        didSet {
            tableView.reloadData()
        }
    }

    // for a bug fix — see note in Search extension below
    private var searchEditBeginDate = Date()
    
    lazy var helpButton: UIBarButtonItem = { HelpDrawerCoordinator.helpBarButton(for: self) }()
    var helpDrawerType: HelpDrawer { .hashtags }

    private lazy var searchController: UISearchController = {
        let controller = UISearchController(searchResultsController: nil)
        controller.searchResultsUpdater = self
        controller.searchBar.delegate = self
        controller.searchBar.isTranslucent = false
        controller.obscuresBackgroundDuringPresentation = false
        controller.hidesNavigationBarDuringPresentation = false
        return controller
    }()

    private lazy var tableView: UITableView = {
        let view = UITableView.forVerse()
        view.dataSource = self
        view.delegate = self
        view.estimatedRowHeight = 54
        view.refreshControl = self.refreshControl
        view.rowHeight = 54
        view.sectionHeaderHeight = 0
        view.separatorColor = UIColor.separator.middle
        view.addSeparatorAsHeaderView()
        return view
    }()

    private lazy var refreshControl: UIRefreshControl = {
        let control = UIRefreshControl.forAutoLayout()
        control.addTarget(self, action: #selector(refreshControlValueChanged(control:)), for: .valueChanged)
        return control
    }()

    // text on which to filter results
    private var searchFilter = "" {
        didSet {
            applySearchFilter()
        }
    }

    // MARK: Lifecycle

    init() {
        super.init(scrollable: false, title: .channels)
        navigationItem.rightBarButtonItems = [helpButton]
    }

    required init?(coder aDecoder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.searchController = self.searchController
        Layout.fill(view: self.view, with: self.tableView)
        self.addLoadingAnimation()
        self.load()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        CrashReporting.shared.record("Did Show Channels")
        Analytics.shared.trackDidShowScreen(screenName: "channels")
        HelpDrawerCoordinator.showFirstTimeHelp(for: self)
    }

    // MARK: Load and refresh

    private func load(animated: Bool = false) {
        Bots.current.hashtags { [weak self] hashtags, error in
            CrashReporting.shared.reportIfNeeded(error: error)
            Log.optional(error)
            self?.removeLoadingAnimation()
            self?.refreshControl.endRefreshing()
            
            if let error = error {
                self?.alert(error: error)
            } else {
                self?.update(with: hashtags, animated: animated)
            }
        }
    }

    private func update(with hashtags: [Hashtag], animated: Bool = true) {
        self.allChannels = hashtags
        self.tableView.reloadData()
    }

    func applySearchFilter() {
        if self.searchFilter.isEmpty {
            self.channels = allChannels
        } else {
            let filter = searchFilter.replacingOccurrences(of: "#", with: "").lowercased()
            channels = allChannels.filter { channel in
                channel.name.lowercased().contains(filter)
            }
        }
    }

    // MARK: Actions

    @objc
    func refreshControlValueChanged(control: UIRefreshControl) {
        control.beginRefreshing()
        load()
    }
    
    // MARK: Notifications

    override func registerNotifications() {
        super.registerNotifications()
        self.registerDidRefresh()
    }

    override func deregisterNotifications() {
        super.deregisterNotifications()
        self.deeregisterDidRefresh()
    }
}

extension ChannelsViewController: TopScrollable {
    func scrollToTop() {
        self.tableView.scrollToTop()
    }
}

extension ChannelsViewController: UISearchResultsUpdating, UISearchBarDelegate {

    func updateSearchResults(for searchController: UISearchController) {
        Analytics.shared.trackDidTapSearchbar(searchBarName: "channels")
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

extension ChannelsViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        channels.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell
        if let reusedCell = tableView.dequeueReusableCell(withIdentifier: "cell") {
            cell = reusedCell
        } else {
            cell = UITableViewCell(style: .subtitle, reuseIdentifier: "cell")
        }
        let hashtag = self.channels[indexPath.row]
        cell.accessoryType = .disclosureIndicator
        cell.textLabel?.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        cell.textLabel?.text = hashtag.string
        cell.selectionStyle = .none
        cell.backgroundColor = .cardBackground
        
        let postText = (hashtag.count == 1) ? Text.Post.one.text : Text.Post.many.text
        
        cell.detailTextLabel?.text = "\(hashtag.count) \(postText)"
        
        return cell
    }
}

// "\(f[0]!)"

extension ChannelsViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        Analytics.shared.trackDidSelectItem(kindName: "channel")
        let controller = ChannelViewController(with: channels[indexPath.row])
        self.navigationController?.pushViewController(controller, animated: true)
    }
}
