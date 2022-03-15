//
//  BlockButton.swift
//  Planetary
//
//  Created by Christoph on 11/6/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit
import Logger
import Analytics

class BlockButton: PillButton {

    var relationship: Relationship? {
        didSet {
            NotificationCenter.default.removeObserver(self)

            guard let relationship = self.relationship else {
                self.isHidden = true
                return
            }

            self.isSelected = relationship.isBlocking
            self.isHidden = relationship.identity == relationship.other

            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(relationshipDidChange(notification:)),
                                                   name: relationship.notificationName,
                                                   object: nil)
        }
    }

    // executed after a follow or unfollow is performed
    // the Bool is true for following, false when not following
    var onUpdate: ((Bool) -> Void)?

    init(color: UIColor = UIColor.tint.default) {
        super.init(primaryColor: color, secondaryColor: color)
        self.setTitle(.block, selected: .blocked)
        self.setImage(UIImage.verse.buttonBlock, selected: UIImage.verse.buttonBlocked)
    }

    override func defaultAction() {

        guard let relationship = self.relationship else {
            assertionFailure("button action was called, but no relationship is setup yet.")
            return
        }
        
        Analytics.shared.trackDidTapButton(buttonName: "block")

        let shouldBlock = !self.isSelected

        func complete() {
            AppController.shared.hideProgress()
            self.isEnabled = true
            relationship.reloadAndNotify()
            self.onUpdate?(shouldBlock)
        }

        //AppController.shared.showProgress()
        self.isEnabled = false

        if shouldBlock {
            Bots.current.block(relationship.other) { _, error in
                Log.optional(error)
                CrashReporting.shared.reportIfNeeded(error: error)
                
                if error != nil {
                    Analytics.shared.trackDidBlockIdentity()
                }
                
                complete()
            }
        } else {
            Bots.current.unblock(relationship.other) { _, error in
                Log.optional(error)
                CrashReporting.shared.reportIfNeeded(error: error)
                
                if error != nil {
                    Analytics.shared.trackDidUnblockIdentity()
                }
                
                AppController.shared.missionControlCenter.sendMission()
                
                complete()
            }
        }
    }

    @objc func relationshipDidChange(notification: Notification) {
        guard let relationship = notification.relationship else { return }
        self.relationship = relationship
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
