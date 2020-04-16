//
//  RelationshipButton.swift
//  Planetary
//
//  Created by Zef Houssney on 9/30/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import UIKit

class RelationshipButton: IconButton {

    private var relationship: Relationship
    private var otherUserName: String
    private var content: KeyValue

    init(with relationship: Relationship, name: String, content: KeyValue) {

        self.relationship = relationship
        self.otherUserName = name
        self.content = content

        super.init(icon: UIImage.verse.relationship)

        relationship.load {
            self.configureImage()
        }

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(relationshipDidChange(notification:)),
                                               name: relationship.notificationName,
                                               object: nil)
    }

    func configureImage() {
        if self.relationship.isBlocking {
            self.image = UIImage.verse.relationshipBlocked
        } else if relationship.isFollowing {
            self.image = UIImage.verse.relationshipFollowing
        } else {
            self.image = UIImage.verse.relationship
        }
    }

    typealias ActionData = (title: Text, style: UIAlertAction.Style, action: () -> Void)

    override func defaultAction() {
        self.relationship.load {
            let actionData: [ActionData] = [
                (.follow,   .default, self.follow),
                (.unfollow, .default, self.unfollow),

//                (.addFriend,    .default,     self.follow),
//                (.removeFriend, .destructive, self.unfollow),

                (.blockUser,   .destructive, self.blockUser),
//                (.unblockUser, .default,     self.unblockUser),

                (.reportPost, .destructive, self.reportPost),
                (.reportUser, .destructive, self.reportUser),

                (.cancel,     .cancel, {})
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

            AppController.shared.choose(from: actions, title: self.otherUserName)
        }
    }

    // MARK: Actions

    func follow() {
        // manually override the image for immediate feedback, assuming success
        // but will be reverted in case of failure
        self.relationship.isFollowing = true
        self.relationship.notifyUpdate()

        Bots.current.follow(self.relationship.other) { (contact, error) in
            if let error = error {
                let detail = "Failed to follow: \(error)"
                Log.unexpected(.botError, detail)
            }
            self.relationship.load(reload: true) {
                self.relationship.notifyUpdate()
                AppController.shared.mainViewController?.homeViewController?.load()
            }
        }
    }

    func unfollow() {
        // manually override the image for immediate feedback, assuming success
        // but will be reverted in case of failure
        self.relationship.isFollowing = false
        self.relationship.notifyUpdate()

        Bots.current.unfollow(self.relationship.other) { (contact, error) in
            if let error = error {
                let detail = "Failed to unfollow: \(error)"
                Log.unexpected(.botError, detail)
            }
            self.relationship.load(reload: true) {
                self.relationship.notifyUpdate()
                AppController.shared.mainViewController?.homeViewController?.load()
            }
        }
    }

    func addFriend() {
        AppController.shared.alert(title: "Unimplemented", message: "TODO: Implement add friend.", cancelTitle: Text.ok.text)
    }

    func removeFriend() {
        AppController.shared.alert(title: "Unimplemented", message: "TODO: Implement remove friend.", cancelTitle: Text.ok.text)
    }


    func blockUser() {
        AppController.shared.promptToBlock(self.content.value.author, name: self.otherUserName)
    }

    func unblockUser() {
        AppController.shared.alert(title: "Unimplemented", message: "TODO: Implement unblock user.", cancelTitle: Text.ok.text)
    }

    func reportUser() {
        let controller = Support.newTicketViewController(from: self.relationship.identity,
                                                         reporting: self.relationship.other,
                                                         name: self.otherUserName)
        AppController.shared.push(controller)
    }

    func reportPost() {
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

extension Support.Reason {

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
        return UIAlertAction(title: Text.cancel.text,
                             style: .cancel,
                             handler: nil)
    }
}

