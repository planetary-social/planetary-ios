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

class RelationshipButton: IconButton {

    private var relationship: Relationship
    private var otherUserName: String
    private var content: KeyValue

    init(with relationship: Relationship, name: String, content: KeyValue) {

        self.relationship = relationship
        self.otherUserName = name
        self.content = content

        super.init(icon: UIImage.verse.optionsOff)

        self.configureImage()

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(relationshipDidChange(notification:)),
                                               name: relationship.notificationName,
                                               object: nil)
    }

    func configureImage() {
        self.image = UIImage.verse.optionsOff
        self.highlightedImage = UIImage.verse.optionsOn
    }

    typealias ActionData = (title: Text, style: UIAlertAction.Style, action: () -> Void)

    override func defaultAction() {
        Analytics.shared.trackDidTapButton(buttonName: "options")
        self.relationship.load {
            let actionData: [ActionData] = [
                (.follow, .default, self.follow),
                (.unfollow, .default, self.unfollow),
                (.copyMessageIdentifier, .default, self.copyMessageIdentifier),
                (.shareThisMessage, .default, self.shareMessage),

//                (.addFriend,    .default,     self.follow),
//                (.removeFriend, .destructive, self.unfollow),

                (.blockUser, .destructive, self.blockUser),
//                (.unblockUser, .default,     self.unblockUser),

                (.reportPost, .destructive, self.reportPost),
                (.reportUser, .destructive, self.reportUser),

                (.cancel, .cancel, {})
            ]

            let actions: [UIAlertAction] = actionData.compactMap {

                (title, style, action) in
                let alertAction = UIAlertAction(title: title.text,
                                                style: style,
                                                handler: { _ in action() })

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

    func addFriend() {
        Analytics.shared.trackDidSelectAction(actionName: "add_friend")
        AppController.shared.alert(title: "Unimplemented", message: "TODO: Implement add friend.", cancelTitle: Text.ok.text)
    }

    func removeFriend() {
        Analytics.shared.trackDidSelectAction(actionName: "remove_friend")
        AppController.shared.alert(title: "Unimplemented", message: "TODO: Implement remove friend.", cancelTitle: Text.ok.text)
    }
    
    func copyMessageIdentifier() {
        Analytics.shared.trackDidSelectAction(actionName: "copy_message_identifier")
        UIPasteboard.general.string = content.key
        AppController.shared.showToast(Text.identifierCopied.text)
    }
    
    func shareMessage() {
        guard let publicLink = content.key.publicLink else {
            AppController.shared.alert(message: Text.Error.couldNotGenerateLink.text)
            return
        }
        Analytics.shared.trackDidSelectAction(actionName: "share_message")
        let activityController = UIActivityViewController(activityItems: [publicLink], applicationActivities: nil)
        AppController.shared.present(activityController, animated: true)
        if let popOver = activityController.popoverPresentationController {
            popOver.sourceView = self
        }
    }

    func blockUser() {
        Analytics.shared.trackDidSelectAction(actionName: "block_identity")
        AppController.shared.promptToBlock(self.content.value.author, name: self.otherUserName)
    }

    func unblockUser() {
        Analytics.shared.trackDidSelectAction(actionName: "unblock_identity")
        AppController.shared.alert(title: "Unimplemented", message: "TODO: Implement unblock user.", cancelTitle: Text.ok.text)
    }

    func reportUser() {
        Analytics.shared.trackDidSelectAction(actionName: "report_user")
        guard let controller = Support.shared.newTicketViewController(from: self.relationship.identity, reporting: self.relationship.other, name: self.otherUserName) else {
            AppController.shared.alert(
                title: Text.error.text,
                message: Text.Error.supportNotConfigured.text,
                cancelTitle: Text.ok.text
            )
            return
        }
        AppController.shared.push(controller)
    }

    func reportPost() {
        Analytics.shared.trackDidSelectAction(actionName: "report_post")
        AppController.shared.report(self.content,
                                    in: self.superview(of: UITableViewCell.self),
                                    from: self.relationship.identity)
    }

    // this allows other Relationship objects to notify redundant Relationship objects
    // of any changes, so they can all respond to changes together.
    @objc func relationshipDidChange(notification: Notification) {
        guard let relationship = notification.userInfo?[Relationship.infoKey] as? Relationship else {
            return
        }
        self.relationship = relationship
        self.configureImage()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension SupportReason {

    var string: String {
        switch self {
            case .abusive: return Text.Reporting.abusive.text
            case .copyright: return Text.Reporting.copyright.text
            case .offensive: return Text.Reporting.offensive.text
            case .other: return Text.Reporting.other.text
        }
    }
}

extension UIAlertAction {

    static func cancel() -> UIAlertAction {
        UIAlertAction(title: Text.cancel.text,
                             style: .cancel,
                             handler: nil)
    }
}
