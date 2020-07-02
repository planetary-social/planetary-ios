//
//  FollowingTableViewController.swift
//  Planetary
//
//  Created by Martin Dutra on 7/2/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import UIKit

class FollowingTableViewController: AboutTableViewController {

    var identity: Identity

    init(identity: Identity) {
        self.identity = identity
        super.init(style: .grouped)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Following"
        self.load()
    }

    func load() {
        Bots.current.follows(identity: self.identity) { (abouts: [About], error) in
            Log.optional(error)
            CrashReporting.shared.reportIfNeeded(error: error)
            DispatchQueue.main.async {
                self.title = Text.followingShortCount.text(["count": "\(abouts.count)"])
                self.abouts = abouts
                self.tableView.reloadData()
            }
        }
    }
}
