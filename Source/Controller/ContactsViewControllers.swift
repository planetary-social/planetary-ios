//
//  ContactsViewControllers.swift
//  FBTT
//
//  Created by Christoph on 5/2/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit
import Analytics
import CrashReporting

class ContactsViewController: ContentViewController, AboutTableViewDelegate {

    private let identity: Identity
    private let dataSource: AboutTableViewDataSource

    private lazy var tableView: UITableView = {
        let view = UITableView.forVerse()
        view.dataSource = self.dataSource
        view.delegate = self.dataSource
        view.prefetchDataSource = self.dataSource
        view.separatorColor = UIColor.separator.middle
        view.addSeparatorAsHeaderView()
        return view
    }()

    init(title: Text, identity: Identity, identities: [Identity] = []) {
        self.identity = identity
        self.dataSource = AboutTableViewDataSource(identities: identities)
        super.init(scrollable: false, dynamicTitle: title.text(["count": "\(identities.count)"]))
        self.dataSource.delegate = self
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        Layout.fill(view: self.view, with: self.tableView)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        CrashReporting.shared.record("Did Show Contacts")
        Analytics.shared.trackDidShowScreen(screenName: "contacts")
    }

    func reload() {
        self.tableView.reloadData()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

