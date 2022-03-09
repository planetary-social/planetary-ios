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

class PreviewSettingsViewController: DebugTableViewController {

    deinit {
        self.deregisterApplicationWillEnterForeground()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title = Text.Preview.title.text
        self.registerApplicationWillEnterForeground()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        CrashReporting.shared.record("Did Show Advanced Settings")
        Analytics.shared.trackDidShowScreen(screenName: "advanced_settings")
    }

    internal override func updateSettings() {
        self.settings = [self.blocks(), self.reset(), self.debug()]
        super.updateSettings()
    }

    @objc override func applicationWillEnterForeground() {
        self.updateSettings()
    }

    // MARK: Blocks

    private func blocks() -> DebugTableViewController.Settings {
        var settings: [DebugTableViewCellModel] = []

        settings += [DebugTableViewCellModel(title: Text.Blocking.usersYouHaveBlocked.text,
                                             valueClosure:
            {
                cell in
                guard let identity = Bots.current.identity else { return }
                cell.showActivityIndicator()
                Bots.current.blocks(identity: identity) {
                    identities, error in
                    cell.hideActivityIndicator(andShow: .disclosureIndicator)
                    cell.detailTextLabel?.text = "\(identities.count)"
                }
            },
                                             actionClosure:
            {
                [unowned self] cell in
                let controller = BlockedUsersViewController()
                self.navigationController?.pushViewController(controller, animated: true)
            })]

        return (Text.Blocking.blockedUsers.text, settings, Text.Blocking.footer.text)
    }

    // MARK: Reset / offboarding

    private func reset() -> DebugTableViewController.Settings {
        var settings: [DebugTableViewCellModel] = []

        settings += [DebugTableViewCellModel(title: Text.Offboarding.resetApplicationAndIdentity.text,
                                             actionClosure:
            {
                [unowned self] cell in
                self.confirmOffboard()
            })]

        return (Text.Offboarding.reset.text, settings, Text.Offboarding.resetFooter.text)
    }

    private func confirmOffboard() {
        self.confirm(
            title: Text.Offboarding.resetConfirmTitle.text,
            message: Text.Offboarding.resetConfirmMessage.text,
            isDestructive: true,
            confirmTitle: Text.Offboarding.reset.text
        ) {
            self.confirmOffboardAgain()
        }
    }

    private func confirmOffboardAgain() {
        self.confirm(
            title: Text.Offboarding.resetConfirmAgainTitle.text,
            message: Text.Offboarding.resetConfirmAgainMessage.text,
            isDestructive: true,
            confirmTitle: Text.Offboarding.reset.text
        ) {
            self.offboard()
        }
    }

    private func offboard() {
        AppController.shared.showProgress(after: 0)
        Offboarding.offboard() {
            [weak self] error in
            AppController.shared.hideProgress()
            guard let me = self else { return }
            if me.didError(error) { return }
            else { me.relaunch() }
        }
    }

    private func didError(_ error: OffboardingError?) -> Bool {
        guard let error = error else { return false }
        CrashReporting.shared.reportIfNeeded(error: error)
        Log.optional(error)
        switch error {
            case .apiError:
                self.confirmTryAgain(message: Text.Offboarding.resetApiErrorTryAgain.text)
            case .botError:
                self.confirmTryAgain(message: Text.Offboarding.resetBotErrorTryAgain.text)
            default: break
        }
        return true
    }

    private func confirmTryAgain(message: String) {
        self.confirm(
            title: Text.Onboarding.somethingWentWrong.text,
            message: message,
            isDestructive: true,
            confirmTitle: Text.tryAgain.text
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

        settings += [DebugTableViewCellModel(title: Text.Debug.debugMenu.text,
                                             valueClosure: {
                cell in
                cell.accessoryType = .disclosureIndicator
            },
                                             actionClosure: {
                [unowned self] cell in
                let controller = DebugViewController()
                controller.shouldAddDismissButton = false
                self.navigationController?.pushViewController(controller, animated: true)
            })]

        return (Text.Debug.debugTitle.text, settings, Text.Debug.debugFooter.text)
    }
    
}
