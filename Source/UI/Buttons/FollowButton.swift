//
//  FollowButton.swift
//  Planetary
//
//  Created by Zef Houssney on 10/2/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import UIKit

class FollowButton: PillButton {

    var relationship: Relationship? {
        didSet {
            NotificationCenter.default.removeObserver(self)

            guard let relationship = self.relationship else {
                self.isHidden = true
                return
            }

            self.isSelected = !relationship.isFollowing
            self.isHidden = relationship.identity == relationship.other

            NotificationCenter.default.addObserver(self, selector: #selector(relationshipDidChange(notification:)), name: relationship.notificationName, object: nil)
        }
    }

    // executed after a follow or unfollow is performed
    // the Bool is true for following, false when not following
    var onUpdate: ((Bool) -> Void)?

    override init(primaryColor: UIColor = .primaryAction, secondaryColor: UIColor = .secondaryAction) {
        super.init(primaryColor: primaryColor, secondaryColor: secondaryColor)

        self.setTitle(.following, selected: .follow)
        self.setImage(UIImage.verse.buttonFollowing, selected: UIImage.verse.buttonFollow)
    }

    override func defaultAction() {
        guard let relationship = self.relationship else {
            assertionFailure("Follow button action was called, but no relationship is setup yet.")
            return
        }

        Analytics.shared.trackDidTapButton(buttonName: "follow")
        
        let shouldFollow = self.isSelected

        func complete() {
            AppController.shared.hideProgress()
            self.isEnabled = true
            relationship.reloadAndNotify()

            self.onUpdate?(shouldFollow)
        }

        AppController.shared.showProgress()
        self.isEnabled = false
        if shouldFollow {
            Bots.current.follow(relationship.other) { contact, error in
                Log.optional(error)
                CrashReporting.shared.reportIfNeeded(error: error)
                
                if error != nil {
                    Analytics.shared.trackDidFollowIdentity()
                }
                
                complete()
            }
        } else {
            Bots.current.unfollow(relationship.other) { contact, error in
                Log.optional(error)
                CrashReporting.shared.reportIfNeeded(error: error)
                
                if error != nil {
                    Analytics.shared.trackDidUnfollowIdentity()
                }
                
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
