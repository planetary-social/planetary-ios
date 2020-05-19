//
//  SettingsViewController.swift
//  FBTT
//
//  Created by Christoph on 8/8/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

// It turns out that DebugTableViewController works really well
// for the design of the settings, so we're just gonna use it for now.
class SettingsViewController: DebugTableViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title = Text.settings.text
        self.addDismissBarButtonItem()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        CrashReporting.shared.record("Did Show Settings")
        Analytics.shared.trackDidShowScreen(screenName: "settings")
    }

    internal override func updateSettings() {
        self.settings = [self.directory(),
                         self.push(),
                         self.usage(),
                         self.managePubs(),
                         self.preview()]
        super.updateSettings()
    }

    // MARK: User directory

    private var inDirectory: Bool?

    private func directory() -> DebugTableViewController.Settings {
        var settings: [DebugTableViewCellModel] = []

        settings += [DebugTableViewCellModel(title: Text.showMeInDirectory.text,
                                             valueClosure:
            {
                cell in
                cell.showActivityIndicator()
                DirectoryAPI.shared.me {  [weak self] (person, error) in
                    DispatchQueue.main.async {
                        let inDirectory = person?.in_directory ?? false
                        self?.inDirectory = inDirectory
                        cell.detailTextLabel?.text = inDirectory.yesOrNo
                        cell.hideActivityIndicator(andShow: .disclosureIndicator)
                    }
                }
            },
                                             actionClosure:
            {
                [unowned self] cell in
                let controller = UserDirectorySettingsViewController(inDirectory: self.inDirectory)
                self.navigationController?.pushViewController(controller, animated: true)
            })]

        return (Text.userDirectory.text, settings, nil)
    }

    // MARK: Push

    private lazy var pushToggle: UISwitch = {
        let toggle = UISwitch.default()
        toggle.addTarget(self,
                         action: #selector(self.pushNotificationsToggleValueChanged(toggle:)),
                         for: .valueChanged)
        return toggle
    }()

    private func push() -> DebugTableViewController.Settings {
        var settings: [DebugTableViewCellModel] = []

        settings += [DebugTableViewCellModel(title: Text.Push.enabled.text,
                                             valueClosure:
            {
                [unowned self] cell in
                cell.showActivityIndicator()
                AppController.shared.arePushNotificationsEnabled() {
                    [weak self] enabled in
                    cell.hideActivityIndicator()
                    guard let toggle = self?.pushToggle else { return }
                    toggle.isOn = enabled
                    cell.accessoryView = toggle
                }
            },
                                             actionClosure: nil)]

        return (Text.Push.title.text, settings, Text.Push.footer.text)
    }

    /// Asks the AppController to prompt for push notification permissions.  The returned status
    /// can be used to set or reset the toggle, depending on if this is the first time the authorization
    /// status has been tested, or if there are OS settings for push that need to be respected.
    @objc private func pushNotificationsToggleValueChanged(toggle: UISwitch) {
        AppController.shared.promptForPushNotifications(in: self) {
            status in
            guard status != .notDetermined else { return }
            toggle.setOn(status == .authorized, animated: true)
        }
    }

    // MARK: Usage & Analytics

    private func usage() -> DebugTableViewController.Settings {
        var settings: [DebugTableViewCellModel] = []

        settings += [DebugTableViewCellModel(title: Text.analyticsAndCrash.text,
                                             valueClosure:
            {
                cell in
                cell.accessoryType = .disclosureIndicator
                cell.detailTextLabel?.text = Analytics.shared.isEnabled.yesOrNo
            },
                                             actionClosure:
            {
                [unowned self] cell in
                let controller = DataUsageSettingsViewController()
                self.navigationController?.pushViewController(controller, animated: true)
            })]

        return (Text.usageData.text, settings, nil)
    }
    
    // MARK: Manage Pubs
    
    private func managePubs() -> DebugTableViewController.Settings {
        var settings: [DebugTableViewCellModel] = []
        
        settings += [DebugTableViewCellModel(title: Text.ManagePubs.title.text,
                                         valueClosure:
        {
            cell in
            cell.accessoryType = .disclosureIndicator
        },
                                         actionClosure:
        {
            [unowned self] cell in
            let controller = ManagePubsViewController()
            self.navigationController?.pushViewController(controller, animated: true)
        })]
        
        return (Text.ManagePubs.header.text, settings, Text.ManagePubs.footer.text)
    }

    // MARK: Preview

    private func preview() -> DebugTableViewController.Settings {
        var settings: [DebugTableViewCellModel] = []

        settings += [DebugTableViewCellModel(title: Text.Preview.title.text,
                                             valueClosure:
            {
                cell in
                cell.accessoryType = .disclosureIndicator
            },
                                             actionClosure:
            {
                [unowned self] cell in
                let controller = PreviewSettingsViewController()
                self.navigationController?.pushViewController(controller, animated: true)
            })]

        return (Text.Preview.title.text, settings, Text.Preview.footer.text)
    }
}
