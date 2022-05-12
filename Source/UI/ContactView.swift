//
//  ContactView.swift
//  FBTT
//
//  Created by Martin on 4/18/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

class ContactView: KeyValueView {

    let imageView: AvatarImageView = {
        let view = AvatarImageView()
        view.constrainSize(to: Layout.contactAvatarSize)
        return view
    }()

    let label: UILabel = {
        let label = UILabel.forAutoLayout()
        label.lineBreakMode = .byCharWrapping
        label.numberOfLines = 1
        label.font = UIFont.verse.contactName
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    let followerCountLabel: UILabel = {
        let label = UILabel.forAutoLayout()
        label.textColor = UIColor.text.detail
        label.font = UIFont.verse.contactFollowerCount
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
        return label
    }()

    let stackView: UIStackView = {
        let stackView = UIStackView.forAutoLayout()
        stackView.axis = .vertical
        stackView.alignment = .leading
        stackView.spacing = 5
        return stackView
    }()

    let followButton: FollowButton = {
        let followButton = FollowButton()
        followButton.height = 22
        followButton.fontSize = 12
        return followButton
    }()

    private var image: ImageMetadata?

    init() {
        super.init(frame: CGRect.zero)
        self.useAutoLayout()
        self.backgroundColor = .cardBackground

        let targetHeight: CGFloat = 120
        let verticalMargin = floor((targetHeight - Layout.contactAvatarSize) / 2)

        Layout.fillLeft(of: self,
                        with: self.imageView,
                        insets: UIEdgeInsets(top: verticalMargin, left: 0, bottom: -verticalMargin, right: 0),
                        respectSafeArea: false)

        addSubview(stackView)
        stackView.constrainLeading(toTrailingOf: imageView, constant: Layout.horizontalSpacing)
        stackView.constrainTrailingToSuperview()
        stackView.centerYAnchor.constraint(equalTo: imageView.centerYAnchor).isActive = true
        stackView.addArrangedSubview(label)
        stackView.addArrangedSubview(followerCountLabel)
        stackView.addArrangedSubview(hashtagsLabel)
        stackView.addArrangedSubview(followButton)

        hashtagsLabel.delegate = self
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(with identity: Identity, about: About?) {
        if let about = about {
            self.label.text = about.nameOrIdentity
            self.imageView.set(image: about.image)
        } else {
            self.label.text = identity
        }
        self.setRelationship(to: identity)
    }

    func update(numberOfFollowers: Int, numberOfFollows: Int) {
        let string = "Following numberOfFollows • Followed by numberOfFollowers"

        let primaryColor = [NSAttributedString.Key.foregroundColor:  UIColor.text.default]
        let secondaryColor = [NSAttributedString.Key.foregroundColor:  UIColor.text.detail]

        let attributedString = NSMutableAttributedString(string: string, attributes: secondaryColor)
        attributedString.replaceCharacters(in: (attributedString.string as NSString).range(of: "numberOfFollows"),
                                           with: NSAttributedString(string: "\(numberOfFollows)",
                                                                    attributes: primaryColor))
        attributedString.replaceCharacters(in: (attributedString.string as NSString).range(of: "numberOfFollowers"),
                                           with: NSAttributedString(string: "\(numberOfFollowers)",
                                                                    attributes: primaryColor))
        
        followerCountLabel.attributedText = attributedString
    }

    func update(hashtags: [Hashtag]) {
        if hashtags.isEmpty {
            hashtagsLabel.removeFromSuperview()
        } else {
            stackView.insertArrangedSubview(hashtagsLabel, at: 2)
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

    func setRelationship(to identity: Identity) {
        if let me = Bots.current.identity {
            let relationship = Relationship(from: me, to: identity)

            relationship.load {
                self.followButton.relationship = relationship
            }
        }
    }

    // allows us to cancel the image download when reusing for a new cell
    private var imageLoadingTask: URLSessionDataTask?

    private func loadImage(for person: Person) {
        self.imageLoadingTask = self.imageView.load(for: person)
    }

    func reset() {
        self.label.text = ""
        self.imageLoadingTask?.cancel()
        self.imageView.image = UIImage.verse.missingAbout
    }
}

extension ContactView: UITextViewDelegate {

    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        let hashtag = URL.absoluteString
        AppController.shared.pushChannelViewController(for: hashtag)
        return false
    }
}
