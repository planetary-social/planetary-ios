//
//  UIViewController+Block.swift
//  Planetary
//
//  Created by Christoph on 11/4/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit
import Logger
import Analytics
import CrashReporting

extension UIViewController {

    // MARK: Prompt to block user

    func promptToBlock(_ identity: Identity, name: String? = nil) {

        let name = name ?? Localized.Blocking.thisUser.text
        let buttonTitle = Localized.Blocking.buttonTitle.text(["name": name])
        let alertTitle = Localized.Blocking.alertTitle.text(["name": name])

        var actions: [UIAlertAction] = []
        let action = UIAlertAction(title: buttonTitle, style: .destructive) {
            [weak self] _ in
            self?._block(identity)
        }
        actions += [action]
        actions += [UIAlertAction.cancel()]

        self.choose(from: actions, title: alertTitle)
    }

    private func _block(_ identity: Identity) {
        // AppController.shared.showProgress()
        Bots.current.block(identity) { [weak self] (_, error) in
            Log.optional(error)
            CrashReporting.shared.reportIfNeeded(error: error)
            AppController.shared.hideProgress()
            if let error = error {
                self?.alert(error: error)
            } else {
                Analytics.shared.trackDidBlockIdentity()
            }
        }
    }

    // MARK: didBlockUser notification

    func registerDidBlockUser() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(didBlockUser(notification:)),
                                               name: .didBlockUser,
                                               object: nil)
    }

    func deregisterDidBlockUser() {
        NotificationCenter.default.removeObserver(self,
                                                  name: .didBlockUser,
                                                  object: nil)
    }

    @objc
    func didBlockUser(notification: Notification) {
        // subclass are encouraged to override
    }
}
