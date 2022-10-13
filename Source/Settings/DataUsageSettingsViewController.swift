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

    private lazy var on = DebugTableViewCellModel(title: Localized.sendAnalytics.text,
                                                  valueClosure: {
            cell in
            cell.accessoryType = Analytics.shared.isEnabled ? .checkmark : .none
        },
                                                  actionClosure: {
            [unowned self] _ in
            self.toggle(enabled: true)
        })

    private lazy var off = DebugTableViewCellModel(title: Localized.dontSendAnalytics.text,
                                                   valueClosure: {
            cell in
            cell.accessoryType = Analytics.shared.isEnabled ? .none : .checkmark
        },
                                                   actionClosure: {
            [unowned self] _ in
            self.toggle(enabled: false)
        })

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title = Localized.analyticsAndCrash.text
        self.updateSettings()
    }

    override internal func updateSettings() {
        self.settings = [("", [self.on, self.off], Localized.analyticsMessage.text)]
        super.updateSettings()
    }

    private func toggle(enabled: Bool) {
        enabled ? Analytics.shared.optIn() : Analytics.shared.optOut()
        self.updateSettings()
    }
}
