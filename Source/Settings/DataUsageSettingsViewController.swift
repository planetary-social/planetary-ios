//
//  DataUsageSettingsViewController.swift
//  FBTT
//
//  Created by Christoph on 8/8/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit
import Analytics

class DataUsageSettingsViewController: DebugTableViewController {

    private lazy var on = DebugTableViewCellModel(title: Text.sendAnalytics.text,
                                                  valueClosure:
        {
            cell in
            cell.accessoryType = Analytics.shared.isEnabled ? .checkmark : .none
        },
                                                  actionClosure:
        {
            [unowned self] cell in
            self.toggle(enabled: true)
        })

    private lazy var off = DebugTableViewCellModel(title: Text.dontSendAnalytics.text,
                                                   valueClosure:
        {
            cell in
            cell.accessoryType = Analytics.shared.isEnabled ? .none : .checkmark
        },
                                                   actionClosure:
        {
            [unowned self] cell in
            self.toggle(enabled: false)
        })

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title = Text.analyticsAndCrash.text
        self.updateSettings()
    }

    internal override func updateSettings() {
        self.settings = [("", [self.on, self.off], Text.analyticsMessage.text)]
        super.updateSettings()
    }

    private func toggle(enabled: Bool) {
        enabled ? Analytics.shared.optIn() : Analytics.shared.optOut()
        self.updateSettings()
    }
}
