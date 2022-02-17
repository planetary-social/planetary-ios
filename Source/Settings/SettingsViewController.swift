//
//  SettingsViewController.swift
//  FBTT
//
//  Created by Christoph on 8/8/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit
import Logger

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
        self.settings = [self.publicWebHosting(),
                         self.push(),
                         self.usage(),
                         self.managePubs(),
                         self.preview()]
        super.updateSettings()
    }

    // MARK: Public web hosting

    private lazy var publicWebHostingToggle: UISwitch = {
        let toggle = UISwitch.default()
        toggle.addTarget(self,
                         action: #selector(self.publicWebHostingToggleValueChanged(toggle:)),
                         for: .valueChanged)
        return toggle
    }()

    private func publicWebHosting() -> DebugTableViewController.Settings {
        let valueClosure = { (_ cell: UITableViewCell) -> Void in
            cell.showActivityIndicator()
            Bots.current.about { [weak self] (about, error) in
                cell.hideActivityIndicator()
                let isPublicWebHostingEnabled = about?.publicWebHosting ?? false
                self?.publicWebHostingToggle.isOn = isPublicWebHostingEnabled
                cell.accessoryView = self?.publicWebHostingToggle
            }
        }

        var settings: [DebugTableViewCellModel] = []
        settings += [DebugTableViewCellModel(title: Text.PublicWebHosting.enabled.text,
                                             valueClosure: valueClosure,
                                             actionClosure: nil)]

        return (Text.PublicWebHosting.title.text, settings, Text.PublicWebHosting.footer.text)
    }

    @objc private func publicWebHostingToggleValueChanged(toggle: UISwitch) {
        let isPublicWebHostingEnabled = toggle.isOn
        //AppController.shared.showProgress()
        Bots.current.about { [weak self] (about, error) in
            if let error = error {
                Log.optional(error)
                CrashReporting.shared.reportIfNeeded(error: error)
                AppController.shared.hideProgress()
                toggle.isOn = !isPublicWebHostingEnabled
                self?.alert(error: error)
            } else if let about = about {
                let newAbout = about.mutatedCopy(publicWebHosting: isPublicWebHostingEnabled)
                Bots.current.publish(content: newAbout) { (_, error) in
                    Log.optional(error)
                    CrashReporting.shared.reportIfNeeded(error: error)

                    AppController.shared.hideProgress()
                    if let error = error {
                        self?.alert(error: error)
                        toggle.isOn = !isPublicWebHostingEnabled
                    }
                }
            } else {
                let error = AppError.unexpected
                Log.optional(error)
                CrashReporting.shared.reportIfNeeded(error: error)
                AppController.shared.hideProgress()
                toggle.isOn = !isPublicWebHostingEnabled
                self?.alert(error: error)
            }
        }
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
