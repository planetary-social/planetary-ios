//
//  FollowerTableViewController.swift
//  Planetary
//
//  Created by Martin Dutra on 7/2/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import UIKit
import Logger
import CrashReporting

class FollowerTableViewController: AboutTableViewController {

    var identity: Identity
    var startingAbouts: [About]?

    init(identity: Identity, followers: [About]? = nil) {
        self.identity = identity
        self.startingAbouts = followers
        super.init(style: .grouped)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        if let abouts = self.startingAbouts, !abouts.isEmpty {
            self.title = Localized.followedByShortCount.text(["count": "\(abouts.count)"])
            self.allAbouts = abouts.sorted()
        } else {
            self.title = Localized.followedByShortCount.text(["count": "0"])
            self.load { }
        }
    }

    override func load(completion: @escaping () -> Void) {
        Bots.current.followers(identity: self.identity) { (abouts: [About], error) in
            Log.optional(error)
            CrashReporting.shared.reportIfNeeded(error: error)
            self.title = Localized.followedByShortCount.text(["count": "\(abouts.count)"])
            self.allAbouts = abouts.sorted()
            completion()
        }
    }
}
