//
//  ExtendedAboutView.swift
//  Planetary
//
//  Created by Martin on 4/18/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit
import SkeletonView

class ExtendedAboutView: MessageUIView {

    let imageView: AvatarImageView = {
        let view = AvatarImageView(borderColor: .primaryAction, borderWidth: 2)
        view.constrainSize(to: Layout.contactAvatarSize)
        view.isSkeletonable = true
        return view
    }()

    let nameLabel: UILabel = {
        let label = UILabel.forAutoLayout()
        label.lineBreakMode = .byCharWrapping
        label.numberOfLines = 1
        label.font = UIFont.verse.contactName
        label.lineBreakMode = .byTruncatingTail
        label.linesCornerRadius = 7
        label.isSkeletonable = true
        return label
    }()
    
    let contactIdentity: UILabel = {
        let label = UILabel.forAutoLayout()
        label.lineBreakMode = .byCharWrapping
        label.numberOfLines = 1
        label.font = UIFont.verse.contactIdentity
        label.lineBreakMode = .byTruncatingTail
        label.textColor = UIColor.text.detail
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
        label.lastLineFillPercent = 100
        label.backgroundColor = .clear
        return label
    }()

    let labelStackView: UIStackView = {
        let stackView = UIStackView.forAutoLayout()
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.spacing = 8
        stackView.isSkeletonable = true
        return stackView
    }()
    
    let followButtonContainer: UIView = {
        let view = UIView()
        view.isSkeletonable = true
        return view
    }()

    let followButton: FollowButton = {
        let followButton = FollowButton(
            displayTitle: false,
            followingImage: UIImage.verse.buttonBigFollowing,
            followImage: UIImage.verse.buttonBigFollow
        )
        followButton.isSkeletonable = true
        return followButton
    }()

    init() {
        super.init(frame: CGRect.zero)
        self.useAutoLayout()
        self.backgroundColor = .clear
        
        addSubview(labelStackView)

        Layout.fillLeft(
            of: self,
            with: self.imageView,
            respectSafeArea: false
        )

        Layout.center(followButton, in: followButtonContainer)
        followButton.trailingAnchor.constraint(equalTo: followButtonContainer.trailingAnchor).isActive = true
        followButton.leadingAnchor.constraint(equalTo: followButtonContainer.leadingAnchor).isActive = true

        let nameAndIdentityStackView = UIStackView.forAutoLayout()
        nameAndIdentityStackView.axis = .vertical
        nameAndIdentityStackView.alignment = .leading
        nameAndIdentityStackView.spacing = 5
        nameAndIdentityStackView.isSkeletonable = true
        nameAndIdentityStackView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        nameAndIdentityStackView.addArrangedSubview(nameLabel)
        nameAndIdentityStackView.addArrangedSubview(contactIdentity)

        let nameIdentityAndFollowButtonStackView = UIStackView.forAutoLayout()
        nameIdentityAndFollowButtonStackView.axis = .horizontal
        nameIdentityAndFollowButtonStackView.spacing = 5
        nameIdentityAndFollowButtonStackView.isSkeletonable = true
        nameIdentityAndFollowButtonStackView.distribution = .fill
        nameIdentityAndFollowButtonStackView.addArrangedSubview(nameAndIdentityStackView)
        nameIdentityAndFollowButtonStackView.addArrangedSubview(followButtonContainer)

        labelStackView.constrainLeading(toTrailingOf: imageView, constant: Layout.horizontalSpacing)
        labelStackView.constrainTrailingToSuperview()
        labelStackView.centerYAnchor.constraint(equalTo: imageView.centerYAnchor).isActive = true
        labelStackView.addArrangedSubview(nameIdentityAndFollowButtonStackView)
        followerCountLabel.setContentHuggingPriority(.required, for: .vertical)
        labelStackView.addArrangedSubview(followerCountLabel)
        labelStackView.addArrangedSubview(hashtagsLabel)

        hashtagsLabel.delegate = self

        isSkeletonable = true

        reset()
    }

    required init?(coder aDecoder: NSCoder) {
        nil
    }

    override func reset() {
        super.reset()
        update(with: Identity.null, about: nil)
        update(socialStats: SocialStats(numberOfFollowers: 0, numberOfFollows: 0))
        nameLabel.text = "placeholder name"
        hashtagsLabel.text = "#hashta #hashta #hashta" // no letters below the baseline
        contactIdentity.text = "@abc123abc123"
        labelStackView.arrangedSubviews.forEach { $0.isHidden = false }
        hashtagsLabel.isHidden = true
        contactIdentity.isHidden = false

        showAnimatedSkeleton()
        layoutSkeletonIfNeeded()
        DispatchQueue.main.async {
            self.layoutSkeletonIfNeeded()
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        layoutSkeletonIfNeeded()
    }
    
    func update(with identity: Identity, about: About?, star: Star? = nil) {
        if let about = about {
            self.nameLabel.text = about.nameOrIdentity
            self.imageView.set(image: about.image)
            self.contactIdentity.text = String(about.identity.prefix(7))
            nameLabel.hideSkeleton()
            contactIdentity.hideSkeleton()
            imageView.hideSkeleton()
        } else {
            self.nameLabel.text = identity
            self.imageView.set(image: nil)
            self.contactIdentity.isHidden = true
            nameLabel.hideSkeleton()
            imageView.hideSkeleton()
        }
        if identity == Identity.null {
            followButton.isHidden = false
            followButton.isSelected = false
        } else if let myIdentity = Bots.current.identity {
            followButton.isHidden = false
            let relationship = Relationship(from: myIdentity, to: identity)
            relationship.load {
                self.followButton.relationship = relationship
                self.followButton.hideSkeleton()
            }
        } else {
            followButton.isHidden = true
        }
        followButton.star = star
    }

    /// Show the social stats (number of followers and follows) in this cell.
    /// If nil, it will show a "This user seems to be outside your network" label.
    func update(socialStats: SocialStats?) {
        let primaryColor = [NSAttributedString.Key.foregroundColor: UIColor.text.default]
        let secondaryColor = [NSAttributedString.Key.foregroundColor: UIColor.text.detail]

        guard let socialStats = socialStats else {
            let attributedString = NSMutableAttributedString(
                string: Text.userOusideNetwork.text,
                attributes: secondaryColor
            )
            followerCountLabel.attributedText = attributedString
            followerCountLabel.hideSkeleton()
            return
        }
        let numberOfFollowers = socialStats.numberOfFollowers
        let numberOfFollows = socialStats.numberOfFollows
        let string = Text.followStats.text

        let attributedString = NSMutableAttributedString(string: string, attributes: secondaryColor)
        attributedString.replaceCharacters(
            // swiftlint:disable legacy_objc_type
            in: (attributedString.string as NSString).range(of: "{{numberOfFollows}}"),
            // swiftlint:enable legacy_objc_type
            with: NSAttributedString(
                string: "\(numberOfFollows)",
                attributes: primaryColor
            )
        )
        attributedString.replaceCharacters(
            // swiftlint:disable legacy_objc_type
            in: (attributedString.string as NSString).range(of: "{{numberOfFollowers}}"),
            // swiftlint:enable legacy_objc_type
            with: NSAttributedString(
                string: "\(numberOfFollowers)",
                attributes: primaryColor
            )
        )
        followerCountLabel.attributedText = attributedString
        followerCountLabel.hideSkeleton()
    }

    func update(hashtags: [Hashtag]) {
        if hashtags.isEmpty {
            hashtagsLabel.isHidden = true
        } else {
            hashtagsLabel.isHidden = false
            let string = ""
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
            hashtagsLabel.layer.cornerRadius = 0 // hack because SkeletonView won't round the corners for some reason
            hashtagsLabel.hideSkeleton()
        }
    }
}

extension ExtendedAboutView: UITextViewDelegate {

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
