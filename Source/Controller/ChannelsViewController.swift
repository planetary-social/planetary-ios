//
//  ChannelsViewController.swift
//  FBTT
//
//  Created by Christoph on 6/25/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

class ChannelsViewController: ContentViewController {

    private let dataSource = HashtagTableViewDataSource()

    private lazy var tableView: UITableView = {
        let view = UITableView.forVerse()
        view.dataSource = self.dataSource
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

    // MARK: Lifecycle

    init() {
        super.init(scrollable: false, title: .channels)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        Layout.fill(view: self.view, with: self.tableView)
        self.addLoadingAnimation()
        self.load()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.deeregisterDidSyncAndRefresh()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.registerDidSyncAndRefresh()
    }

    // MARK: Load and refresh

    private func load() {
        Bots.current.hashtags() {
            [weak self] hashtags, error in
            CrashReporting.shared.reportIfNeeded(error: error)
            Log.optional(error)
            self?.removeLoadingAnimation()
            self?.refreshControl.endRefreshing()
            
            if let error = error {
                self?.alert(error: error)
            } else {
                self?.update(with: hashtags, animated: false)
            }
        }
    }

    private func refresh() {
        self.load()
    }

    private func update(with hashtags: [Hashtag], animated: Bool = true) {
        self.dataSource.hashtags = hashtags
        self.tableView.reloadData()
    }

    // MARK: Actions

    @objc func refreshControlValueChanged(control: UIRefreshControl) {
        control.beginRefreshing()
        self.refresh()
    }
    
    // MARK: Notifications

    override func registerNotifications() {
        super.registerNotifications()
        self.registerDidSyncAndRefresh()
    }

    override func deregisterNotifications() {
        super.deregisterNotifications()
        self.deeregisterDidSyncAndRefresh()
    }

    /// Refreshes the view,  but only if this is the top controller, not when there are any child
    /// controllers.  The notification will also only be received when the view is not visible,
    /// check out `viewDidAppear()` and `viewDidDisappear()`.  This is because
    /// we don't want the view to be updated while someone is looking/scrolling it.
    override func didSyncAndRefresh(notification: NSNotification) {
        guard self.navigationController?.topViewController == self else { return }
        self.refresh()
    }
}

extension ChannelsViewController: TopScrollable {
    func scrollToTop() {
        self.tableView.scrollToTop()
    }
}

fileprivate class HashtagTableViewDataSource: NSObject, UITableViewDataSource {

    var hashtags: [Hashtag] = []

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.hashtags.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "cell")
        let hashtag = self.hashtags[indexPath.row]
        cell.accessoryType = .disclosureIndicator
        cell.textLabel?.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        cell.textLabel?.text = hashtag.string
        cell.selectionStyle = .none
        
        let post_text = (hashtag.count == 1) ? "post" : "posts"
        let ago = hashtag.timeAgo()
        
        cell.detailTextLabel?.text = "\(hashtag.count) \(post_text) last updated \(ago)"
        
        return cell
    }
}

//"\(f[0]!)"

extension ChannelsViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let controller = ChannelViewController(with: self.dataSource.hashtags[indexPath.row])
        self.navigationController?.pushViewController(controller, animated: true)
    }
}
