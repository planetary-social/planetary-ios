//
//  ManagePubsViewController.swift
//  Planetary
//
//  Created by Martin Dutra on 3/3/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

class ManagePubsViewController: UITableViewController {
    
    var knownPubs = [KnownPub]()
    
    // MARK: Lifecycle
    
    convenience init() {
        self.init(style: .grouped)
        self.title = Text.ManagePubs.title.text
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.load()
    }

    // MARK: Load and refresh

    private func load() {
        Bots.current.knownPubs { [weak self] (knownPubs, error) in
            Log.optional(error)
            CrashReporting.shared.reportIfNeeded(error: error)
            if let error = error {
                self?.alert(error: error)
            } else {
                self?.knownPubs = knownPubs
                self?.tableView.reloadData()
            }
        }
    }
    
    // MARK:- UITableViewDataSource
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        if knownPubs.isEmpty {
            return 1
        }
        return 2
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return 1
        }
        return knownPubs.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell") ?? UITableViewCell(style: .default, reuseIdentifier: "cell")
        if indexPath.section == 0 {
            cell.textLabel?.text = "Redeem an invitation"
        } else {
            cell.textLabel?.text = knownPubs[indexPath.row].ForFeed
        }
        cell.accessoryType = .disclosureIndicator
        return cell
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return "Adding Pubs"
        }
        return "Your Pubs"
    }
    
    // MARK:- UITableViewDelegate
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let targetController = self.navigationController
        if indexPath.section == 0 {
            let controller = RedeemInviteViewController()
            controller.saveCompletion = { [weak self] _ in
                self?.load()
                targetController?.popViewController(animated: true)
            }
            targetController?.pushViewController(controller, animated: true)
        } else {
            let controller = AboutViewController(with: knownPubs[indexPath.row].ForFeed)
            targetController?.pushViewController(controller, animated: true)
        }
    }
}
