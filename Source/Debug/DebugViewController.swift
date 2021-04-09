import Foundation
import UIKit

class DebugViewController: DebugTableViewController {

    var shouldAddDismissButton: Bool = true
    
    // Since we change the 3 primary aspects of the SSB
    // configuration, we want to make sure the changes were
    // really intended, so this configuration is modified
    // in any UI that sets network, identity, and bot.  Then
    // when this controller is being closed, the user is
    // prompted to ensure that the configuration changes
    // should be applied.
    private var configuration = AppConfiguration.current

    override func viewDidLoad() {
        super.viewDidLoad()
        if shouldAddDismissButton {
            self.addDismissBarButtonItem()
        }
        self.navigationItem.title = Text.debug.text
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        CrashReporting.shared.record("Did Show Debug")
        Analytics.shared.trackDidShowScreen(screenName: "debug")
    }

    internal override func updateSettings() {
        self.settings = [self.application(),
                         self.features(),
                         self.analytics(),
                         self.configurations(),
                         self.bots(),
                         self.operations()]
        super.updateSettings()
    }

    private func application() -> DebugTableViewController.Settings {

        var settings: [DebugTableViewCellModel] = []

        settings += [DebugTableViewCellModel(title: "Version",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure:
            {
                cell in
                cell.detailTextLabel?.text = Bundle.main.versionAndBuild
            },
                                             actionClosure: nil)]

        settings += [DebugTableViewCellModel(title: "Bundle",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure:
            {
                cell in
                cell.detailTextLabel?.text = Bundle.main.bundleIdentifier
            },
                                             actionClosure: nil)]

        settings += [DebugTableViewCellModel(title: "Localhost",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure:
            {
                cell in
                cell.detailTextLabel?.text = UIDevice.current.localhost()
            },
                                             actionClosure: nil)]

        return ("Application", settings, nil)
    }

    private func features() -> DebugTableViewController.Settings {

        var settings: [DebugTableViewCellModel] = []

        settings += [DebugTableViewCellModel(title: "Caches",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure:
            {
                cell in
                cell.accessoryType = .disclosureIndicator
            },
                                             actionClosure:
            {
                cell in
                let controller = CachesViewController()
                self.navigationController?.pushViewController(controller, animated: true)
            })]

        settings += [DebugTableViewCellModel(title: "Onboarding",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure:
            {
                cell in
                cell.accessoryType = .disclosureIndicator
            },
                                             actionClosure:
            {
                cell in
                let controller = DebugOnboardingViewController()
                self.navigationController?.pushViewController(controller, animated: true)
            })]

        settings += [DebugTableViewCellModel(title: "Layout",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure:
            {
                cell in
                cell.accessoryType = .disclosureIndicator
            },
                                             actionClosure:
            {
                cell in
                let controller = DebugUIViewController()
                self.navigationController?.pushViewController(controller, animated: true)
            })]

        settings += [DebugTableViewCellModel(title: "Posts",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure:
            {
                cell in
                cell.accessoryType = .disclosureIndicator
            },
                                             actionClosure:
            {
                cell in
                let controller = DebugPostsViewController()
                self.navigationController?.pushViewController(controller, animated: true)
            })]

        settings += [DebugTableViewCellModel(title: "Support - Help Center",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure:
            {
                cell in
                cell.accessoryType = .disclosureIndicator
            },
                                             actionClosure:
            {
                cell in
                guard let controller = Support.shared.mainViewController() else {
                    self.alert(message: Text.Error.supportNotConfigured.text)
                    return
                }
                self.navigationController?.pushViewController(controller, animated: true)
            })]

        settings += [DebugTableViewCellModel(title: "Support - My Tickets",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure:
            {
                cell in
                cell.accessoryType = .disclosureIndicator
            },
                                             actionClosure:
            {
                cell in
                guard let controller = Support.shared.myTicketsViewController(from: Bots.current.identity) else {
                    self.alert(message: Text.Error.supportNotConfigured.text)
                    return
                }
                self.navigationController?.pushViewController(controller, animated: true)
            })]

        settings += [DebugTableViewCellModel(title: "Support - New Bug Report",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure:
            {
                cell in
                cell.accessoryType = .disclosureIndicator
            },
                                             actionClosure:
            {
                cell in
                guard let controller = Support.shared.newTicketViewController() else {
                    self.alert(message: Text.Error.supportNotConfigured.text)
                    return
                }
                self.navigationController?.pushViewController(controller, animated: true)
            })]

        settings += [DebugTableViewCellModel(title: "Show peer-to-peer widget",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure:
            {
                cell in
                let toggle = UISwitch()
                toggle.isOn = UserDefaults.standard.showPeerToPeerWidget
                toggle.addTarget(self, action: #selector(self.peerToPeerToggleValueChanged(toggle:)), for: .valueChanged)
                cell.accessoryView = toggle
            },
                                             actionClosure: nil)]

        return ("Features", settings, nil)
    }

    @objc private func peerToPeerToggleValueChanged(toggle: UISwitch) {
        UserDefaults.standard.showPeerToPeerWidget = toggle.isOn
    }

    private func analytics() -> DebugTableViewController.Settings {

        var settings: [DebugTableViewCellModel] = []

        settings += [DebugTableViewCellModel(title: "Events (tracked / all)",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure:
            {
                cell in
                cell.accessoryType = .disclosureIndicator
                cell.detailTextLabel?.text = "\(UserDefaults.standard.trackedEvents().count) / \(Analytics.shared.lexicon().count)"
            },
                                             actionClosure:
            {
                [weak self] cell in
                let controller = DebugAnalyticsViewController()
                self?.navigationController?.pushViewController(controller, animated: true)
            })]

        settings += [DebugTableViewCellModel(title: "Tap to clear tracked events",
                                         cellReuseIdentifier: DebugValueTableViewCell.className,
                                         valueClosure: nil,
                                         actionClosure:
            {
                [unowned self] cell in
                UserDefaults.standard.clearTrackedEvents()
                self.updateSettings()
            })]

        return ("Analytics", settings, "The lexicon shows all possible EVENT_ELEMENT_NAME strings that Mixpanel will show.  Events that have been sent to Mixpanel will appear highlighted.  This is useful to verify that the expected events are being sent.")
    }

    private func configurations() -> DebugTableViewController.Settings {

        var settings: [DebugTableViewCellModel] = []

        let configurations = AppConfigurations.current

        for configuration in configurations {
            settings += [DebugTableViewCellModel(title: configuration.name,
                                                 cellReuseIdentifier: DebugValueTableViewCell.className,
                                                 valueClosure:
                {
                    cell in
                    cell.detailTextLabel?.text = configuration.network?.name
                    let selected = (configuration.identity == AppConfiguration.current?.identity)
                    cell.accessoryType = selected ? .checkmark : .disclosureIndicator
                },
                                                 actionClosure:
                {
                    [unowned self] cell in
                    let controller = AppConfigurationViewController(with: configuration)
                    self.navigationController?.pushViewController(controller, animated: true)
                }
            )]
        }

        settings += [DebugTableViewCellModel(title: "Create new configuration and secret",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure:
            {
                cell in
                cell.accessoryType = .disclosureIndicator
            },
                                             actionClosure:
            {
                [unowned self] cell in
                Bots.current.createSecret {
                    secret, error in
                    Log.optional(error)
                    guard let secret = secret else { return }
                    let controller = AppConfigurationViewController(with: secret)
                    self.navigationController?.pushViewController(controller, animated: true)
                }
            }
        )]

        settings += [DebugTableViewCellModel(title: "Add new configuration from secret",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure:
            {
                cell in
                cell.accessoryType = .disclosureIndicator
            },
                                             actionClosure:
            {
                [unowned self] cell in
                let controller = SecretViewController()
                self.navigationController?.pushViewController(controller, animated: true)
            }
        )]

        return ("Configurations", settings, nil)
    }

    private func bots() -> DebugTableViewController.Settings {

        var settings: [DebugTableViewCellModel] = []

        settings += [DebugTableViewCellModel(title: "GoBot",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure:
            {
                cell in
                cell.accessoryType = .disclosureIndicator
            },
                                             actionClosure:
            {
                cell in
                let controller = BotViewController(bot: GoBot.shared, configuration: self.configuration)
                self.navigationController?.pushViewController(controller, animated: true)
            }
        )]

        settings += [DebugTableViewCellModel(title: "Mission Control Center",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure:
            {
                cell in
                cell.detailTextLabel?.text = "\(AppController.shared.missionControlCenter.state)"
            },
                                             actionClosure: nil)]

        return ("Bots", settings, nil)
    }
    
    private func operations() -> DebugTableViewController.Settings {

        var settings: [DebugTableViewCellModel] = []

        settings += [DebugTableViewCellModel(title: "Download logs",
                                         cellReuseIdentifier: DebugValueTableViewCell.className,
                                         valueClosure: nil,
                                         actionClosure:
        {
            [unowned self] cell in
            let alertController = UIAlertController(title: "Share Logs", message: nil, preferredStyle: .actionSheet)
            alertController.addAction(UIAlertAction(title: "All files", style: .default, handler: { (_) in
                Analytics.shared.trackDidShareLogs()
                self.shareLogs(shouldZip: false, allFiles: true, cell: cell)
            }))
            alertController.addAction(UIAlertAction(title: "All files in a ZIP file", style: .default, handler: { (_) in
                Analytics.shared.trackDidShareLogs()
                self.shareLogs(shouldZip: true, allFiles: true, cell: cell)
            }))
            alertController.addAction(UIAlertAction(title: "Recent files", style: .default, handler: { (_) in
                Analytics.shared.trackDidShareLogs()
                self.shareLogs(shouldZip: false, allFiles: false, cell: cell)
            }))
            alertController.addAction(UIAlertAction(title: "Recent files in a ZIP file", style: .default, handler: { (_) in
                Analytics.shared.trackDidShareLogs()
                self.shareLogs(shouldZip: true, allFiles: false, cell: cell)
            }))
            alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            self.present(alertController: alertController)
        })]
        
        settings += [DebugTableViewCellModel(title: "Simulate onboarding",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure: nil,
                                             actionClosure:
            {
                [unowned self] cell in
                self.relaunchIntoOnboarding()
            })]

        settings += [DebugTableViewCellModel(title: "Logout and login",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure: nil,
                                             actionClosure:
            {
                [unowned self] cell in
                self.logout()
            })]

        settings += [DebugTableViewCellModel(title: "Logout and onboard",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure: nil,
                                             actionClosure:
            {
                [unowned self] cell in
                self.logoutAndRelaunch()
        })]

        return ("Operations", settings, nil)
    }

    // MARK: Actions

    private func configurationHasChanged() -> Bool {
        let changed = self.configuration != AppConfiguration.current
        return changed
    }

    @objc private func relaunchIntoOnboarding() {
        UserDefaults.standard.simulateOnboarding = true
        if self.configurationHasChanged() {
            self.confirm(message: "The configuration has changed, but cannot be changed when launching into the onboarding flow.",
                         confirmTitle: "Discard changes and relaunch",
                         confirmClosure: self.discardConfigurationAndRelaunch)
        } else {
            self.relaunch()
        }
    }

    @objc internal override func didPressDismiss() {
        if AppConfiguration.hasCurrent == false {
            self.confirm(message: "There is no selected configuration.  This will relaunch the app into onboarding.",
                         confirmTitle: "Relaunch",
                         confirmClosure: self.applyConfigurationAndDismiss)
            return
        }

        if self.configuration != AppConfiguration.current {
            self.confirm(message: "The configuration has changed and will require restarting the app.",
                         isDestructive: true,
                         cancelTitle: "Discard changes",
                         cancelClosure: self.discardConfigurationAndDismiss,
                         confirmTitle: "Apply changes and restart",
                         confirmClosure: self.applyConfigurationAndDismiss)
        } else {
            self.dismiss(animated: true, completion: nil)
        }
    }

    private func shareLogs(shouldZip: Bool, allFiles: Bool, cell: UITableViewCell) {
        let share = { [weak self] (activityItems: [Any]) in
            let activityController = UIActivityViewController(activityItems: activityItems,
                                                              applicationActivities: nil)
            self?.present(activityController, animated: true)
            if let popOver = activityController.popoverPresentationController {
                popOver.sourceView = cell
            }
        }
        
        let botFileURLs = Bots.current.logFileUrls
        let appFileUrls = Log.fileUrls
        if appFileUrls.isEmpty, botFileURLs.isEmpty {
            self.alert(message: "There aren't logs yet.")
        } else if shouldZip {
            let temporaryDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            let url = temporaryDirectory.appendingPathComponent(UUID().uuidString)
            DispatchQueue.global(qos: .background).async {
                do {
                    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
                    let zipFileURL = temporaryDirectory.appendingPathComponent("\(UUID().uuidString).zip")
                    let copy = { (appFileURL: URL) throws in
                        let destFileURL = url.appendingPathComponent(appFileURL.lastPathComponent)
                        try FileManager.default.copyItem(at: appFileURL, to: destFileURL)
                    }
                    
                    if allFiles {
                        try appFileUrls.forEach{try copy($0)}
                        try botFileURLs.forEach{try copy($0)}
                    } else if let firstAppFileURL = appFileUrls.first, let firstBotFileURL = botFileURLs.first {
                        try copy(firstAppFileURL)
                        try copy(firstBotFileURL)
                    } else if let firstAppFileURL = appFileUrls.first {
                        try copy(firstAppFileURL)
                    } else if let firstBotFileURL = botFileURLs.first {
                        try copy(firstBotFileURL)
                    } else {
                        DispatchQueue.main.async { [weak self] in
                            self?.alert(message: "There aren't logs yet.")
                        }
                    }
                    
                    let coord = NSFileCoordinator()
                    var readError: NSError?
                    coord.coordinate(readingItemAt: url, options: .forUploading, error: &readError) { (zippedURL: URL) -> Void in
                        do {
                            try FileManager.default.copyItem(at: zippedURL, to: zipFileURL)
                        } catch let error {
                            DispatchQueue.main.async { [weak self] in
                                self?.alert(error: error)
                            }
                        }
                        DispatchQueue.main.async {
                            share([zipFileURL])
                        }
                    }
                } catch let error {
                    DispatchQueue.main.async { [weak self] in
                        self?.alert(error: error)
                    }
                }
            }
        } else {
            if allFiles {
                share(appFileUrls + botFileURLs)
            } else if let firstAppFileURL = appFileUrls.first, let firstBotFileURL = botFileURLs.first {
                share([firstAppFileURL, firstBotFileURL])
            } else if let firstAppFileURL = appFileUrls.first {
                share([firstAppFileURL])
            } else if let firstBotFileURL = botFileURLs.first {
                share([firstBotFileURL])
            } else {
                self.alert(message: "There aren't logs yet.")
            }
        }
    }
    
    private func applyConfigurationAndDismiss() {
        Bots.current.logout {
            [weak self] error in
            
            Log.optional(error)
            CrashReporting.shared.reportIfNeeded(error: error)
            
            Analytics.shared.forget()
            CrashReporting.shared.forget()
            
            AppController.shared.relaunch()
            self?.dismiss(animated: true, completion: nil)
        }
    }

    private func discardConfigurationAndDismiss() {
        self.dismiss(animated: true, completion: nil)
    }

    private func discardConfigurationAndRelaunch() {
        self.relaunch()
    }

    private func clearConfigurationAndRelaunch() {
        self.configuration?.unapply()
        self.applyConfigurationAndDismiss()
    }

    private func relaunch() {
        AppController.shared.launch()
        self.dismiss(animated: true, completion: nil)
    }

    private func logout() {
        self.confirm(message: "Are you sure you want to logout of the current configuration?  Any pending operations will be lost.",
                     isDestructive: true,
                     confirmTitle: "Logout",
                     confirmClosure: {
                        Analytics.shared.trackDidLogout()
                        self.applyConfigurationAndDismiss()
                        
        })
    }

    private func logoutAndRelaunch() {
        self.confirm(message: "Are you sure you want to logout of the current configuration?  Any pending operations will be lost.",
                     isDestructive: true,
                     confirmTitle: "Logout and relaunch",
                     confirmClosure: {
                        Analytics.shared.trackDidLogoutAndOnboard()
                        self.clearConfigurationAndRelaunch()
        })
    }
}
