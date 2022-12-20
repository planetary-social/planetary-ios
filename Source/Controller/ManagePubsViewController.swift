//
//  ManagePubsViewController.swift
//  Planetary
//
//  Created by Martin Dutra on 3/3/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit
import Logger
import CrashReporting
import SwiftUI

class ManagePubsViewController: UITableViewController, KnownPubsTableViewDataSourceDelegate {
    
    lazy var dataSource = KnownPubsTableViewDataSource(pubs: [])
    
    // MARK: Lifecycle
    
    convenience init() {
        self.init(style: .insetGrouped)
        self.title = Localized.ManageRelays.managePubs.text
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.load()
    }

    // MARK: Load and refresh

    private func load() {
        self.dataSource.delegate = self
        self.tableView.dataSource = self.dataSource
        self.tableView.prefetchDataSource = self.dataSource
        Bots.current.joinedPubs { [weak self] (pubs, error) in
            Log.optional(error)
            CrashReporting.shared.reportIfNeeded(error: error)
            if let error = error {
                self?.alert(error: error)
            } else {
                self?.dataSource.pubs = pubs
                self?.tableView.reloadData()
            }
        }
    }
    
    func reload() {
        self.tableView.reloadData()
    }
    
    // MARK: - UITableViewDelegate
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let targetController = self.navigationController
        guard indexPath.section != 0 else {
            let controller = RedeemInviteViewController()
            controller.saveCompletion = { [weak self] _ in
                self?.load()
                targetController?.popViewController(animated: true)
            }
            targetController?.pushViewController(controller, animated: true)
            return
        }
        let identity = dataSource.pubs[indexPath.row].address.key
        let controller = UIHostingController(
            rootView: IdentityViewBuilder().build(identity: identity, botRepository: .shared, appController: .shared)
        )
        targetController?.pushViewController(controller, animated: true)
    }
}
