//
//  ChannelViewController.swift
//  FBTT
//
//  Created by Christoph on 7/6/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

class ChannelViewController: ContentViewController {

    private let hashtag: Hashtag
    private let dataSource = PostReplyDataSource()
    private lazy var delegate = PostReplyDelegate(on: self)
    private let prefetchDataSource = PostReplyDataSourcePrefetching()
    

    
    private lazy var tableView: UITableView = {
        let view = UITableView.forVerse()
        view.dataSource = self.dataSource
        view.delegate = self.delegate
        view.prefetchDataSource = self.prefetchDataSource
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
        Analytics.trackDidShowScreen(screenName: "channel")
    }

    private func load() {
        Bots.current.posts(with: self.hashtag) {
            [weak self] feed, error in
            Log.optional(error)
            self?.removeLoadingAnimation()
            self?.refreshControl.endRefreshing()
            
            if let error = error {
                self?.alert(error: error)
            } else {
                fatalError("TODO: port to new data source")
//                self?.update(with: feed) TODO
            }
        }
    }

    private func refresh() {
        self.load()
    }

    private func update(with feed: KeyValues, animated: Bool = true) {
        self.dataSource.keyValues = feed
        self.tableView.forceReload()
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
        if self.dataSource.keyValues.isEmpty {
            self.navigationController?.remove(viewController: self)
        }
    }
}
