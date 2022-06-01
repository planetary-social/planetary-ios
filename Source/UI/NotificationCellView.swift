//
//  NotificationCellView.swift
//  FBTT
//
//  Created by Christoph on 8/1/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

class NotificationCellView: KeyValueView {

    private let nameFont = UIFont.systemFont(ofSize: 15, weight: .semibold)
    private let actionFont = UIFont.systemFont(ofSize: 15, weight: .regular)
    private let timestampFont = UIFont.systemFont(ofSize: 15, weight: .regular)
    private let contentFont = UIFont.systemFont(ofSize: 15, weight: .regular)
    private var identity: Identity?

    lazy var button: AvatarButton = {
        let button = AvatarButton()
        button.addTarget(self, action: #selector(buttonTouchUpInside), for: .touchUpInside)
        return button
    }()

    let contentLabel: UILabel = {
        let view = UILabel.forAutoLayout()
        view.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        view.numberOfLines = 6
        return view
    }()

    private let followButton = FollowButton()

    var contentTrailingConstraint: NSLayoutConstraint?

    convenience init() {

        self.init(frame: .zero)
        self.backgroundColor = .cardBackground

        Layout.fillTopLeft(of: self, with: self.button, insets: .topLeft)
        self.button.constrainSize(to: Layout.profileThumbSize)

        Layout.fillTopRight(of: self, with: self.followButton, insets: .topRight)

        self.addSubview(self.contentLabel)
        self.contentLabel.constrainLeading(toTrailingOf: self.button, constant: Layout.horizontalSpacing)
        self.contentLabel.pinTopToSuperview(constant: Layout.verticalSpacing)
        self.contentLabel.pinBottomToSuperviewBottom(constant: -Layout.verticalSpacing)
        self.contentTrailingConstraint = self.contentLabel.trailingAnchor.constraint(equalTo: self.trailingAnchor)
        self.contentTrailingConstraint?.isActive = true

        Layout.addSeparator(toBottomOf: self)
    }

    // MARK: Actions

    @objc private func buttonTouchUpInside() {
        guard let identity = self.identity else { return }
        AppController.shared.pushViewController(for: .about, with: identity)
    }

    // MARK: KeyValueUpdateable

    override func update(with keyValue: KeyValue) {

        // remember the author identity
        let identity = keyValue.value.author
        self.identity = identity

        // avatar button
        self.button.setImage(for: keyValue.metadata.author.about)

        // name
        let name = keyValue.metadata.author.about?.nameOrIdentity ?? identity
        let text = NSMutableAttributedString(name,
                                             font: self.nameFont)

        // action
        let shouldHideFollowButton: Bool
        if let doesMention = keyValue.value.content.post?.doesMention(Bots.current.identity) {
            text.append(NSAttributedString(doesMention ? " mentioned you" : " replied",
                                           font: self.actionFont))

            shouldHideFollowButton = true
            self.contentTrailingConstraint?.constant = -Layout.horizontalSpacing
        } else {
            text.append(NSAttributedString(" started following you",
                                           font: self.actionFont))
            shouldHideFollowButton = false
            self.contentTrailingConstraint?.constant = -134
        }

        // set the color for name and action before adding the timestamp
        text.addColorAttribute(UIColor.text.default)

        // timestamp
        text.append(NSAttributedString(" • \(keyValue.userDate.elapsedTimeFromNowString())",
                                       font: self.timestampFont,
                                       color: UIColor.text.notificationTimestamp))

        // content snippet
        if keyValue.value.content.isPost {
            let flattened = Caches.truncatedText.from(keyValue).flattenedString()
            text.append(NSAttributedString("\n\(flattened)",
                                           font: self.contentFont,
                                           color: UIColor.text.notificationContent))
        }

        self.followButton.isHidden = true
        if let me = Bots.current.identity {
            let relationship = Relationship(from: me, to: identity)
            relationship.load {
                self.followButton.relationship = relationship
                self.followButton.isHidden = shouldHideFollowButton
            }
        }

        text.addAttributes(UIFont.paragraphStyleAttribute(lineSpacing: 1))

        // done
        self.contentLabel.attributedText = text
        self.forceNeedsLayout()
    }

    override func reset() {
        self.button.set(image: nil)
        self.contentLabel.text = nil
        self.forceNeedsLayout()
    }

    // TODO move to KeyValueView? or UIView?
    private func forceNeedsLayout() {
        self.setNeedsLayout()
        self.layoutIfNeeded()
    }
}
