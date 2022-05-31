//
//  ContactView.swift
//  FBTT
//
//  Created by Martin on 4/18/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit
import SkeletonView

class ContactView: KeyValueView {

    let imageView: AvatarImageView = {
        let view = AvatarImageView()
        view.constrainSize(to: Layout.contactAvatarSize)
        view.isSkeletonable = true
        return view
    }()

    let label: UILabel = {
        let label = UILabel.forAutoLayout()
        label.lineBreakMode = .byCharWrapping
        label.numberOfLines = 1
        label.font = UIFont.verse.contactName
        label.lineBreakMode = .byTruncatingTail
        label.linesCornerRadius = 7
        label.isSkeletonable = true
        return label
    }()

    let followerCountLabel: UILabel = {
        let label = UILabel.forAutoLayout()
        label.textColor = UIColor.text.detail
        label.font = UIFont.verse.contactFollowerCount
        label.linesCornerRadius = 7
        label.isSkeletonable = true
        return label
    }()

    let hashtagsLabel: UITextView = {
        let label = UITextView.forAutoLayout()
        label.textColor = UIColor.primaryAction
        label.font = UIFont.verse.contactFollowerCount
        label.isScrollEnabled = false
        label.isEditable = false
        label.textContainerInset = .zero
        label.textContainer.lineFragmentPadding = 0
        label.isSkeletonable = true
        label.linesCornerRadius = 7
        return label
    }()

    let stackView: UIStackView = {
        let stackView = UIStackView.forAutoLayout()
        stackView.axis = .vertical
        stackView.alignment = .leading
        stackView.spacing = 5
        stackView.isSkeletonable = true
        return stackView
    }()

    let followButton: FollowButton = {
        let followButton = FollowButton()
        followButton.height = 22
        followButton.fontSize = 12
        followButton.isSkeletonable = true
        return followButton
    }()

    init() {
        super.init(frame: CGRect.zero)
        self.useAutoLayout()
        self.backgroundColor = .cardBackground

        let targetHeight: CGFloat = 120
        let verticalMargin = floor((targetHeight - Layout.contactAvatarSize) / 2)

        Layout.fillLeft(
            of: self,
            with: self.imageView,
            insets: UIEdgeInsets(top: verticalMargin, left: 0, bottom: -verticalMargin, right: 0),
            respectSafeArea: false
        )

        addSubview(stackView)
        stackView.constrainLeading(toTrailingOf: imageView, constant: Layout.horizontalSpacing)
        stackView.constrainTrailingToSuperview()
        stackView.centerYAnchor.constraint(equalTo: imageView.centerYAnchor).isActive = true
        stackView.addArrangedSubview(label)
        stackView.addArrangedSubview(followerCountLabel)
        stackView.addArrangedSubview(hashtagsLabel)
        stackView.addArrangedSubview(followButton)

        hashtagsLabel.delegate = self

        isSkeletonable = true

        reset()
    }

    required init?(coder aDecoder: NSCoder) {
        nil
    }

    override func reset() {
        super.reset()
        update(
            with: Identity.null,
            about: nil,
            socialStats: SocialStats(numberOfFollowers: 0, numberOfFollows: 0),
            hashtags: []
        )
    }

    func update(with identity: Identity, about: About?, socialStats: SocialStats, hashtags: [Hashtag]) {
        update(numberOfFollowers: socialStats.numberOfFollowers, numberOfFollows: socialStats.numberOfFollows)
        update(hashtags: hashtags)
        update(with: identity, about: about)
    }

    private func update(with identity: Identity, about: About?) {
        if let about = about {
            self.label.text = about.nameOrIdentity
            self.imageView.set(image: about.image)
        } else {
            self.label.text = identity
            self.imageView.set(image: nil)
        }
        if identity == Identity.null {
            followButton.removeFromSuperview()
        } else if let myIdentity = Bots.current.identity {
            stackView.addArrangedSubview(followButton)
            let relationship = Relationship(from: myIdentity, to: identity)
            relationship.load {
                self.followButton.relationship = relationship
            }
        } else {
            followButton.removeFromSuperview()
        }
    }

    private func update(numberOfFollowers: Int, numberOfFollows: Int) {
        let string = "Following numberOfFollows • Followed by numberOfFollowers"

        let primaryColor = [NSAttributedString.Key.foregroundColor: UIColor.text.default]
        let secondaryColor = [NSAttributedString.Key.foregroundColor: UIColor.text.detail]

        let attributedString = NSMutableAttributedString(string: string, attributes: secondaryColor)
        attributedString.replaceCharacters(
            // swiftlint:disable legacy_objc_type
            in: (attributedString.string as NSString).range(of: "numberOfFollows"),
            // swiftlint:enable legacy_objc_type
            with: NSAttributedString(
                string: "\(numberOfFollows)",
                attributes: primaryColor
            )
        )
        attributedString.replaceCharacters(
            // swiftlint:disable legacy_objc_type
            in: (attributedString.string as NSString).range(of: "numberOfFollowers"),
            // swiftlint:enable legacy_objc_type
            with: NSAttributedString(
                string: "\(numberOfFollowers)",
                attributes: primaryColor
            )
        )
        followerCountLabel.attributedText = attributedString
    }

    private func update(hashtags: [Hashtag]) {
        if hashtags.isEmpty {
            hashtagsLabel.removeFromSuperview()
        } else {
            stackView.addArrangedSubview(hashtagsLabel)
            let string = "Active on "
            let secondaryColor = [
                NSAttributedString.Key.foregroundColor: UIColor.text.detail,
                NSAttributedString.Key.font: UIFont.verse.contactFollowerCount
            ]
            let attributedString = NSMutableAttributedString(string: string, attributes: secondaryColor)

            for (index, hashtag) in hashtags.enumerated() {
                let link = [
                    NSAttributedString.Key.foregroundColor: UIColor.primaryAction,
                    NSAttributedString.Key.font: UIFont.verse.contactFollowerCount,
                    NSAttributedString.Key.link: hashtag.string
                ] as [NSAttributedString.Key: Any]
                let hashtagAttributedString = NSAttributedString(
                    string: hashtag.string,
                    attributes: link
                )
                attributedString.append(hashtagAttributedString)
                if index < hashtags.count - 1 {
                    attributedString.append(NSAttributedString(string: " ", attributes: secondaryColor))
                }
            }
            hashtagsLabel.attributedText = attributedString
        }
    }

}

extension ContactView: UITextViewDelegate {

    func textView(
        _ textView: UITextView,
        shouldInteractWith URL: URL,
        in characterRange: NSRange,
        interaction: UITextItemInteraction
    ) -> Bool {
        let hashtag = URL.absoluteString
        AppController.shared.pushChannelViewController(for: hashtag)
        return false
    }
}
