//
//  PreviewSettingsViewController.swift
//  FBTT
//
//  Created by Christoph on 8/22/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit
import Logger
import Analytics
import CrashReporting

class PreviewSettingsViewController: DebugTableViewController {

    deinit {
        self.deregisterApplicationWillEnterForeground()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title = Localized.Preview.title.text
        self.registerApplicationWillEnterForeground()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        CrashReporting.shared.record("Did Show Advanced Settings")
        Analytics.shared.trackDidShowScreen(screenName: "advanced_settings")
    }

    override internal func updateSettings() {
        self.settings = [self.blocks(), self.reset(), self.debug()]
        super.updateSettings()
    }

    @objc override func applicationWillEnterForeground() {
        self.updateSettings()
    }

    // MARK: Blocks

    private func blocks() -> DebugTableViewController.Settings {
        var settings: [DebugTableViewCellModel] = []

        settings += [DebugTableViewCellModel(title: Localized.Blocking.usersYouHaveBlocked.text,
                                             valueClosure: {
                cell in
                guard let identity = Bots.current.identity else { return }
                cell.showActivityIndicator()
                Bots.current.blocks(identity: identity) {
                    identities, _ in
                    cell.hideActivityIndicator(andShow: .disclosureIndicator)
                    cell.detailTextLabel?.text = "\(identities.count)"
                }
            },
                                             actionClosure: {
                [unowned self] _ in
                let controller = BlockedUsersViewController()
                self.navigationController?.pushViewController(controller, animated: true)
            })]

        return (Localized.Blocking.blockedUsers.text, settings, Localized.Blocking.footer.text)
    }

    // MARK: Reset / offboarding

    private func reset() -> DebugTableViewController.Settings {
        var settings: [DebugTableViewCellModel] = []

        settings += [
            DebugTableViewCellModel(
                title: Localized.Offboarding.resetIdentity.text,
                valueClosure: { cell in
                    cell.textLabel?.textColor = .systemRed
                },
                actionClosure: { [weak self] _ in
                    self?.confirmOffboard()
                }
            )
        ]

        return (Localized.Offboarding.reset.text, settings, Localized.Offboarding.resetFooter.text)
    }

    private func confirmOffboard() {
        self.confirm(
            title: Localized.Offboarding.resetConfirmTitle.text,
            message: Localized.Offboarding.resetConfirmMessage.text,
            isDestructive: true,
            confirmTitle: Localized.Offboarding.reset.text
        ) {
            self.confirmOffboardAgain()
        }
    }

    private func confirmOffboardAgain() {
        self.confirm(
            title: Localized.Offboarding.resetConfirmAgainTitle.text,
            message: Localized.Offboarding.resetConfirmAgainMessage.text,
            isDestructive: true,
            confirmTitle: Localized.Offboarding.reset.text
        ) {
            self.offboard()
        }
    }

    private func offboard() {
        AppController.shared.showProgress(after: 0)
        Offboarding.offboard {
            [weak self] error in
            AppController.shared.hideProgress()
            guard let me = self else { return }
            if me.didError(error) { return } else { me.relaunch() }
        }
    }

    private func didError(_ error: OffboardingError?) -> Bool {
        guard let error = error else { return false }
        CrashReporting.shared.reportIfNeeded(error: error)
        Log.optional(error)
        switch error {
            case .apiError:
                self.confirmTryAgain(message: Localized.Offboarding.resetApiErrorTryAgain.text)
            case .botError:
                self.confirmTryAgain(message: Localized.Offboarding.resetBotErrorTryAgain.text)
            default: break
        }
        return true
    }

    private func confirmTryAgain(message: String) {
        self.confirm(
            title: Localized.Onboarding.somethingWentWrong.text,
            message: message,
            isDestructive: true,
            confirmTitle: Localized.tryAgain.text
        ) {
            self.offboard()
        }
    }

    private func relaunch() {
        self.dismiss(animated: true) {
            Task {
                await AppController.shared.relaunch()
            }
        }
    }
    
    // MARK: Debug
    
    private func debug() -> DebugTableViewController.Settings {
        var settings: [DebugTableViewCellModel] = []

        settings += [DebugTableViewCellModel(title: Localized.Debug.debugMenu.text,
                                             valueClosure: {
                cell in
                cell.accessoryType = .disclosureIndicator
            },
                                             actionClosure: {
                [unowned self] _ in
                let controller = DebugViewController()
                controller.shouldAddDismissButton = false
                self.navigationController?.pushViewController(controller, animated: true)
            })]

        return (Localized.Debug.debugTitle.text, settings, Localized.Debug.debugFooter.text)
    }
}
