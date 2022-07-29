//
//  FollowButton.swift
//  Planetary
//
//  Created by Zef Houssney on 10/2/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import UIKit
import Logger
import Analytics
import CrashReporting

class FollowButton: PillButton {

    var operationQueue = OperationQueue()
    var shouldDisplayTitle = true
    
    var star: Star? {
        didSet {
            guard shouldDisplayTitle else {
                return
            }
            if star == nil {
                self.setTitle(.following, selected: .follow)
            } else {
                self.setTitle(.following, selected: .join)
            }
        }
    }
    
    var relationship: Relationship? {
        didSet {
            NotificationCenter.default.removeObserver(self)

            guard let relationship = self.relationship else {
                self.isHidden = true
                return
            }

            self.isSelected = !relationship.isFollowing
            self.isHidden = relationship.identity == relationship.other

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(relationshipDidChange(notification:)),
                name: relationship.notificationName,
                object: nil
            )
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

    init(
        primaryColor: UIColor = .primaryAction,
        secondaryColor: UIColor = .secondaryAction,
        displayTitle: Bool = true,
        followingImage: UIImage? = UIImage.verse.buttonFollowing,
        followImage: UIImage? = UIImage.verse.buttonFollow
    ) {
        super.init(primaryColor: primaryColor, secondaryColor: secondaryColor)
        self.shouldDisplayTitle = displayTitle
        if displayTitle {
            self.setTitle(.following, selected: .follow)
        }
        self.setImage(UIImage.verse.buttonFollowing, selected: UIImage.verse.buttonFollow)
    }

    override func defaultAction() {
        Analytics.shared.trackDidTapButton(buttonName: "follow")
        
        let shouldFollow = self.isSelected

        self.isEnabled = false
        let successHandler = { [weak self] in
            if shouldFollow {
                Analytics.shared.trackDidFollowIdentity()
            } else {
                Analytics.shared.trackDidUnfollowIdentity()
            }
            DispatchQueue.main.async {
                AppController.shared.hideProgress()
                self?.isEnabled = true
                self?.relationship?.reloadAndNotify()
                self?.onUpdate?(shouldFollow)
            }
        }
        let errorHandler = { [weak self] (error: Error) in
            Log.optional(error)
            CrashReporting.shared.reportIfNeeded(error: error)
            DispatchQueue.main.async {
                AppController.shared.hideProgress()
                self?.isEnabled = true
                self?.relationship?.reloadAndNotify()
                AppController.shared.alert(error: error)
            }
        }
        if shouldFollow {
            follow(onSuccess: successHandler, onError: errorHandler)
        } else {
            unfollow(onSuccess: successHandler, onError: errorHandler)
        }
    }

    private func follow(onSuccess: @escaping () -> Void, onError: @escaping (Error) -> Void) {
        guard let relationship = self.relationship else {
            onError(AppError.unexpected)
            return
        }
        if let star = self.star {
            let operation = RedeemInviteOperation(star: star, shouldFollow: true)
            operation.completionBlock = {
                switch operation.result {
                case .success, .none:
                    onSuccess()
                case .failure(let error):
                    onError(error)
                }
            }
            self.operationQueue.addOperation(operation)
        } else {
            let operation = FollowOperation(identity: relationship.other)
            operation.completionBlock = {
                if let error = operation.error {
                    onError(error)
                } else {
                    onSuccess()
                }
            }
            self.operationQueue.addOperation(operation)
        }
    }

    private func unfollow(onSuccess: @escaping () -> Void, onError: @escaping (Error) -> Void) {
        guard let relationship = self.relationship else {
            onError(AppError.unexpected)
            return
        }
        let operation = UnfollowOperation(identity: relationship.other)
        operation.completionBlock = {
            if let error = operation.error {
                onError(error)
            } else {
                onSuccess()
            }
        }
        self.operationQueue.addOperation(operation)
    }

    @objc
    func relationshipDidChange(notification: Notification) {
        guard let relationship = notification.relationship else { return }
        self.relationship = relationship
    }

    required init?(coder aDecoder: NSCoder) {
        nil
    }
}
