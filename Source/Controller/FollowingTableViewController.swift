//
//  FollowingTableViewController.swift
//  Planetary
//
//  Created by Martin Dutra on 7/2/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import UIKit
import Logger
import CrashReporting

class FollowingTableViewController: AboutTableViewController {

    var identity: Identity
    var startingAbouts: [About]?

    init(identity: Identity, followings: [About]? = nil) {
        self.identity = identity
        self.startingAbouts = followings
        super.init(style: .grouped)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        if let abouts = self.startingAbouts, !abouts.isEmpty {
            self.title = Text.following.text(["count": "\(abouts.count)"])
            self.allAbouts = abouts.sorted()
        } else {
            self.title = Text.following.text(["count": "0"])
            self.load { }
        }
    }

    override func load(completion: @escaping () -> Void) {
        Bots.current.followings(identity: self.identity) { (abouts: [About], error) in
            Log.optional(error)
            CrashReporting.shared.reportIfNeeded(error: error)
            self.title = Text.following.text(["count": "\(abouts.count)"])
            self.allAbouts = abouts.sorted()
            completion()
        }
    }
}
