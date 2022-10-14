//
//  RelationshipButton.swift
//  Planetary
//
//  Created by Zef Houssney on 9/30/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import UIKit
import Logger
import Analytics
import CrashReporting
import Support
import SwiftUI

class RelationshipButton: IconButton {

    private var relationship: Relationship
    private var otherUserName: String
    private var content: Message

    init(with relationship: Relationship, name: String, content: Message) {

        self.relationship = relationship
        self.otherUserName = name
        self.content = content

        super.init(icon: UIImage.verse.optionsOff)

        self.configureImage()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(relationshipDidChange(notification:)),
            name: relationship.notificationName,
            object: nil
        )
    }

    func configureImage() {
        self.image = UIImage.verse.optionsOff
        self.highlightedImage = UIImage.verse.optionsOn
    }

    typealias ActionData = (title: Localized, style: UIAlertAction.Style, action: () -> Void)

    override func defaultAction() {
        Analytics.shared.trackDidTapButton(buttonName: "options")
        self.relationship.load {
            let actionData: [ActionData] = [
                (.follow, .default, self.follow),
                (.unfollow, .default, self.unfollow),
                (.copyMessageIdentifier, .default, self.copyMessageIdentifier),
                (.shareThisMessage, .default, self.shareMessage),
                (.viewSource, .default, self.viewSource),
                (.blockUser, .destructive, self.blockUser),
                (.reportPost, .destructive, self.reportPost),
                (.reportUser, .destructive, self.reportUser),

                (.cancel, .cancel, {})
            ]

            let actions: [UIAlertAction] = actionData.compactMap { (title, style, action) in
                let alertAction = UIAlertAction(
                    title: title.text,
                    style: style,
                    handler: { _ in action() }
                )

                // here we can return nil for any actions we don't want to appear for the current state.
                if self.relationship.isFollowing {
                    if title == .follow { return nil }
                } else {
                    if title == .unfollow { return nil }
                }

                if self.relationship.isFriend {
                    if title == .addFriend { return nil }
                } else {
                    if title == .removeFriend { return nil }
                }

                if self.relationship.isBlocking {
                    if title == .blockUser { return nil }
                } else {
                    if title == .unblockUser { return nil }
                }

                return alertAction
            }

            AppController.shared.choose(from: actions, sourceView: self)
        }
    }

    // MARK: Actions

    func follow() {
        Analytics.shared.trackDidSelectAction(actionName: "follow_identity")
        
        // manually override the image for immediate feedback, assuming success
        // but will be reverted in case of failure
        self.relationship.isFollowing = true
        self.relationship.notifyUpdate()

        Bots.current.follow(self.relationship.other) { (_, error) in
            Log.optional(error)
            CrashReporting.shared.reportIfNeeded(error: error)
            if error != nil {
                Analytics.shared.trackDidFollowIdentity()
            }
            self.relationship.load(reload: true) {
                self.relationship.notifyUpdate()
                AppController.shared.mainViewController?.homeViewController?.load()
            }
        }
    }

    func unfollow() {
        Analytics.shared.trackDidSelectAction(actionName: "unfollow_identity")
        
        // manually override the image for immediate feedback, assuming success
        // but will be reverted in case of failure
        self.relationship.isFollowing = false
        self.relationship.notifyUpdate()

        Bots.current.unfollow(self.relationship.other) { (_, error) in
            Log.optional(error)
            CrashReporting.shared.reportIfNeeded(error: error)
            if error != nil {
                Analytics.shared.trackDidUnfollowIdentity()
            }
            self.relationship.load(reload: true) {
                self.relationship.notifyUpdate()
                AppController.shared.mainViewController?.homeViewController?.load()
            }
        }
    }

    func copyMessageIdentifier() {
        Analytics.shared.trackDidSelectAction(actionName: "copy_message_identifier")
        UIPasteboard.general.string = content.key
        AppController.shared.showToast(Localized.identifierCopied.text)
    }
    
    func shareMessage() {
        guard let publicLink = content.key.publicLink else {
            AppController.shared.alert(message: Localized.Error.couldNotGenerateLink.text)
            return
        }
        Analytics.shared.trackDidSelectAction(actionName: "share_message")
        let activityController = UIActivityViewController(activityItems: [publicLink], applicationActivities: nil)
        if let popOver = activityController.popoverPresentationController {
            popOver.sourceView = self
        }
        AppController.shared.present(activityController, animated: true)
    }

    func viewSource() {
        Analytics.shared.trackDidSelectAction(actionName: "view_source")
        let viewModel = RawMessageCoordinator(message: content, bot: Bots.current)
        let controller = UIHostingController(rootView: RawMessageView(viewModel: viewModel))
        let navController = UINavigationController(rootViewController: controller)
        AppController.shared.present(navController, animated: true)
    }

    func blockUser() {
        Analytics.shared.trackDidSelectAction(actionName: "block_identity")
        AppController.shared.promptToBlock(self.content.author, name: self.otherUserName)
    }

    func reportUser() {
        Analytics.shared.trackDidSelectAction(actionName: "report_user")
        let reporter = relationship.identity
        let profile = AbusiveProfile(identifier: relationship.other, name: otherUserName)
        guard let controller = Support.shared.newTicketViewController(reporter: reporter, profile: profile) else {
            AppController.shared.alert(
                title: Localized.error.text,
                message: Localized.Error.supportNotConfigured.text,
                cancelTitle: Localized.ok.text
            )
            return
        }
        AppController.shared.push(controller)
    }

    func reportPost() {
        Analytics.shared.trackDidSelectAction(actionName: "report_post")
        AppController.shared.report(
            self.content,
            in: self.superview(of: UITableViewCell.self),
            from: self.relationship.identity
        )
    }

    // this allows other Relationship objects to notify redundant Relationship objects
    // of any changes, so they can all respond to changes together.
    @objc
    func relationshipDidChange(notification: Notification) {
        guard let relationship = notification.userInfo?[Relationship.infoKey] as? Relationship else {
            return
        }
        self.relationship = relationship
        self.configureImage()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        nil
    }
}

extension SupportReason {

    var string: String {
        switch self {
        case .abusive: return Localized.Reporting.abusive.text
        case .copyright: return Localized.Reporting.copyright.text
        case .offensive: return Localized.Reporting.offensive.text
        case .other: return Localized.Reporting.other.text
        }
    }
}

extension UIAlertAction {

    static func cancel() -> UIAlertAction {
        UIAlertAction(
            title: Localized.cancel.text,
            style: .cancel,
            handler: nil
        )
    }
}
