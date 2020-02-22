//
//  IdentitiesViewController.swift
//  FBTT
//
//  Created by Christoph on 5/14/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

class IdentitiesViewController: DebugTableViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title = "Identities"
        self.settings = [self.ssb(), self.planetary(), self.verse()]
    }

    private func ssb() -> DebugTableViewController.Settings {

        var settings: [DebugTableViewCellModel] = []

        for identity in Identities.ssb.all {
            let setting = DebugTableViewCellModel(title: String(describing: identity.key),
                                                 cellReuseIdentifier: DebugValueTableViewCell.className,
                                                 valueClosure:
                {
                    cell in
                    cell.detailTextLabel?.text = identity.value
                },
                                                 actionClosure:
                {
                    cell in
                    UIPasteboard.general.string = cell.detailTextLabel?.text
                })
            settings += [setting]
        }

        return ("SSB", settings, nil)
    }

    private func planetary() -> DebugTableViewController.Settings {

        var settings: [DebugTableViewCellModel] = []

        for identity in Identities.planetary.all {
            let setting = DebugTableViewCellModel(title: String(describing: identity.key),
                                                  cellReuseIdentifier: DebugValueTableViewCell.className,
                                                  valueClosure:
                {
                    cell in
                    cell.detailTextLabel?.text = identity.value
                },
                                                  actionClosure:
                {
                    cell in
                    UIPasteboard.general.string = cell.detailTextLabel?.text
                })
            settings += [setting]
        }

        return ("Planetary", settings, nil)
    }

    private func verse() -> DebugTableViewController.Settings {

        var settings: [DebugTableViewCellModel] = []

        for identity in Identities.verse.all {
            let setting = DebugTableViewCellModel(title: String(describing: identity.key),
                                                  cellReuseIdentifier: DebugValueTableViewCell.className,
                                                  valueClosure:
                {
                    cell in
                    cell.detailTextLabel?.text = identity.value
                },
                                                  actionClosure:
                {
                    cell in
                    UIPasteboard.general.string = cell.detailTextLabel?.text
                })
            settings += [setting]
        }

        return ("Verse (deprecated)", settings, nil)
    }
}
