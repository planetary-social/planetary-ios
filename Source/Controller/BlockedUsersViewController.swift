//
//  BlockedUsersViewController.swift
//  Planetary
//
//  Created by Christoph on 11/6/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit
import Logger
import CrashReporting

class BlockedUsersViewController: ContentViewController, AboutTableViewDelegate {

    private lazy var dataSource: BlockedUsersTableViewDataSource = {
        let source = BlockedUsersTableViewDataSource(identities: [])
        source.delegate = self
        return source
    }()

    private lazy var tableView: UITableView = {
        let view = UITableView.forVerse()
        view.dataSource = self.dataSource
        view.prefetchDataSource = self.dataSource
        view.separatorColor = UIColor.separator.middle
        view.addSeparatorAsHeaderView()
        return view
    }()

    // MARK: Lifecycle

    init() {
        super.init(scrollable: false, dynamicTitle: Text.Blocking.blockedUsers.text)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        Layout.fill(view: self.view, with: self.tableView)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.load()
    }

    // MARK: Load and refresh

    private func load() {
        guard let identity = Bots.current.identity else { return }
        Bots.current.blocks(identity: identity) {
            [weak self] identities, error in
            Log.optional(error)
            CrashReporting.shared.reportIfNeeded(error: error)
            if let error = error {
                self?.alert(error: error)
            } else {
                self?.dataSource.identities = identities
            }
        }
    }

    // MARK: AboutTableViewDelegate

    func reload() {
        self.tableView.reloadData()
    }
}

private class BlockedUsersTableViewDataSource: AboutTableViewDataSource {

    // TODO this is hack to ensure that the cells only show the
    // block button and not the follow button, the other option
    // is to push a flag through the data source, cell, and about
    // view to do the same, but that is too messy right now
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        if let aboutCell = cell as? AboutTableViewCell {
            aboutCell.showBlockButton()
        }
        return cell
    }
}
