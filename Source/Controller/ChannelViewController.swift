//
//  ChannelViewController.swift
//  FBTT
//
//  Created by Christoph on 7/6/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit
import Logger
import Analytics
import CrashReporting

class ChannelViewController: ContentViewController {

    private let hashtag: Hashtag
    
    private lazy var dataSource: PostReplyPaginatedDataSource = {
        let dataSource = PostReplyPaginatedDataSource()
        dataSource.delegate = self
        return dataSource
        
    }()
    
    private lazy var delegate = PostReplyPaginatedDelegate(on: self)
    
    private lazy var tableView: UITableView = {
        let view = UITableView.forVerse()
        view.dataSource = self.dataSource
        view.delegate = self.delegate
        view.prefetchDataSource = self.dataSource
        view.refreshControl = self.refreshControl
        return view
    }()

    private lazy var refreshControl: UIRefreshControl = {
        let control = UIRefreshControl.forAutoLayout()
        control.addTarget(self, action: #selector(refreshControlValueChanged(control:)), for: .valueChanged)
        return control
    }()

    convenience init(named name: String) {
        let hashtag = Hashtag.named(name)
        self.init(with: hashtag)
    }

    init(with hashtag: Hashtag) {
        self.hashtag = hashtag
        super.init(scrollable: false, dynamicTitle: hashtag.string)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.addLoadingAnimation()
        Layout.fill(view: self.contentView, with: self.tableView, respectSafeArea: false)
        self.load()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.load()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        CrashReporting.shared.record("Did Show Channel")
        Analytics.shared.trackDidShowScreen(screenName: "channel")
    }

    private func load(animated: Bool = false) {
        Bots.current.posts(with: self.hashtag) { [weak self] proxy, error in
            Log.optional(error)
            DispatchQueue.main.async { [weak self] in
                self?.removeLoadingAnimation()
                self?.refreshControl.endRefreshing()
                
                if let error = error {
                    self?.alert(error: error)
                } else {
                    self?.update(with: proxy, animated: animated)
                }
            }
        }
    }

    private func refresh() {
        self.load()
    }

    private func update(with proxy: PaginatedKeyValueDataProxy, animated: Bool = true) {
        self.dataSource.update(source: proxy)
        if animated {
            self.tableView.reloadSections(IndexSet(integer: 0), with: .automatic)
        } else {
            self.tableView.forceReload()
        }
    }

    // MARK: Actions

    @objc func refreshControlValueChanged(control: UIRefreshControl) {
        control.beginRefreshing()
        self.load()
    }

    // MARK: Notifications

    override func didBlockUser(notification: NSNotification) {
        guard let identity = notification.object as? Identity else { return }
        self.tableView.deleteKeyValues(by: identity)
    }
}

extension ChannelViewController: PostReplyPaginatedDataSourceDelegate {
    
    func postReplyView(view: PostReplyView, didLoad keyValue: KeyValue) {
        view.postView.tapGesture.tap = {
            [weak self] in
            Analytics.shared.trackDidSelectItem(kindName: "post", param: "area", value: "post")
            self?.pushThreadViewController(with: keyValue)
        }
        view.repliesView.tapGesture.tap = {
            [weak self] in
            Analytics.shared.trackDidSelectItem(kindName: "post", param: "area", value: "replies")
            self?.pushThreadViewController(with: keyValue)
        }

        // open thread and start reply
        view.replyTextView.tapGesture.tap = {
            [weak self] in
            Analytics.shared.trackDidSelectItem(kindName: "post", param: "area", value: "post")
            self?.pushThreadViewController(with: keyValue, startReplying: true)
        }
    }
    
    private func pushThreadViewController(with keyValue: KeyValue, startReplying: Bool = false) {
        let controller = ThreadViewController(with: keyValue, startReplying: startReplying)
        self.navigationController?.pushViewController(controller, animated: true)
    }
    
}
