//
//  CachesViewController.swift
//  Planetary
//
//  Created by Christoph on 12/6/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

class CachesViewController: DebugTableViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title = "Caches"
        self.settings = [self.strings(), self.blobs()]
    }

    private func strings() -> DebugTableViewController.Settings {

        var settings: [DebugTableViewCellModel] = []

        settings += [DebugTableViewCellModel(title: "Post truncated text",
                                         cellReuseIdentifier: DebugValueTableViewCell.className,
                                         valueClosure: {
                cell in
                cell.detailTextLabel?.text = "\(Caches.truncatedText.count)"
            },
                                         actionClosure: nil)]

        settings += [DebugTableViewCellModel(title: "Post truncated text prefills",
                                         cellReuseIdentifier: DebugValueTableViewCell.className,
                                         valueClosure: {
                cell in
                cell.detailTextLabel?.text = "\(Caches.truncatedText.prefillCount)"
            },
                                         actionClosure: nil)]

        settings += [DebugTableViewCellModel(title: "Post text",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure: {
                cell in
                cell.detailTextLabel?.text = "\(Caches.text.count)"
            },
                                             actionClosure: nil)]

        settings += [DebugTableViewCellModel(title: "Tap to invalidate",
                                         cellReuseIdentifier: DebugValueTableViewCell.className,
                                         valueClosure: nil,
                                         actionClosure: {
                [unowned self] _ in
                Caches.truncatedText.invalidate()
                Caches.text.invalidate()
                self.updateSettings()
            })]

        return ("Attributed Strings", settings, nil)
    }

    private func blobs() -> DebugTableViewController.Settings {

        var settings: [DebugTableViewCellModel] = []

        settings += [DebugTableViewCellModel(title: "Datas / Usage",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure: {
                cell in
                let mb = Caches.blobs.estimatedBytes / 1_024 / 1_024
                let string = mb == 0 ? "< 1" : "\(mb)"
                cell.detailTextLabel?.text = "\(Caches.blobs.count) / \(string) MB"
            },
                                             actionClosure: nil)]

        settings += [DebugTableViewCellModel(title: "Tap to invalidate",
                                         cellReuseIdentifier: DebugValueTableViewCell.className,
                                         valueClosure: nil,
                                         actionClosure: {
                [unowned self] _ in
                Caches.blobs.invalidate()
                self.updateSettings()
            })]

        settings += [DebugTableViewCellModel(title: "Identifiers / Completions",
                                         cellReuseIdentifier: DebugValueTableViewCell.className,
                                         valueClosure: {
                cell in
                let text = "\(Caches.blobs.numberOfBlobIdentifiers) / \(Caches.blobs.numberOfBlobCompletions)"
                cell.detailTextLabel?.text = text
            },
                                             actionClosure: nil)]

        settings += [DebugTableViewCellModel(title: "Tap to forget completions",
                                         cellReuseIdentifier: DebugValueTableViewCell.className,
                                         valueClosure: nil,
                                         actionClosure: {
                _ in
                Caches.blobs.forgetCompletions()
                self.updateSettings()
            })]

        return ("Blobs", settings, nil)
    }
}
