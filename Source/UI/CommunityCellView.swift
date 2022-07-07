//
//  CommunityCellView.swift
//  Planetary
//
//  Created by Martin Dutra on 1/30/21.
//  Copyright © 2021 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

class CommunityCellView: UIView {

    let imageView: AvatarImageView = {
        let view = AvatarImageView()
        view.constrainSize(to: Layout.profileThumbSize)
        return view
    }()

    let label: UILabel = {
        let label = UILabel.forAutoLayout()
        label.lineBreakMode = .byCharWrapping
        label.numberOfLines = 1
        label.font = UIFont.verse.aboutCellName
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    let identityLabel: UILabel = {
        let label = UILabel.forAutoLayout()
        label.textColor = UIColor.text.detail
        label.font = UIFont.verse.aboutCellIdentity
        return label
    }()

    let followButton = FollowButton()
    let blockButton = BlockButton()

    private var image: ImageMetadata?

    init() {
        super.init(frame: CGRect.zero)
        self.useAutoLayout()
        self.backgroundColor = .cardBackground

        let targetHeight: CGFloat = 60
        let verticalMargin = floor((targetHeight - Layout.profileThumbSize) / 2)

        Layout.fillLeft(
            of: self,
            with: self.imageView,
            insets: UIEdgeInsets(
                top: verticalMargin,
                left: Layout.horizontalSpacing,
                bottom: verticalMargin,
                right: 0
            ),
            respectSafeArea: false
        )

        self.addSubview(self.label)
        self.label.constrainLeading(toTrailingOf: self.imageView, constant: Layout.horizontalSpacing)
        self.label.constrainTop(toTopOf: self.imageView, constant: -1)
        self.label.setContentHuggingPriority(.defaultLow, for: .horizontal)

        self.addSubview(self.identityLabel)
        self.identityLabel.constrainLeading(to: self.label)
        self.identityLabel.constrainTrailing(toTrailingOf: self.label)
        self.identityLabel.bottomAnchor.constraint(equalTo: self.imageView.bottomAnchor, constant: 1).isActive = true
        self.identityLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        self.identityLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)

        self.addSubview(self.followButton)
        self.followButton.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
        self.followButton.leftAnchor.constraint(equalTo: self.label.rightAnchor, constant: 6).isActive = true
        self.followButton.pinRightToSuperview(constant: -Layout.horizontalSpacing)?.priority = .defaultHigh
        self.followButton.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        self.addSubview(self.blockButton)
        self.blockButton.constrain(to: self.followButton)
        self.blockButton.alpha = 0
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(with star: Star, about: About?) {
        if let about = about {
            self.label.text = about.nameOrIdentity
            self.imageView.set(image: about.image)
        } else {
            self.label.text = star.feed
        }
        self.setIdentityText(identity: star.feed)
        self.followButton.star = star
        self.setRelationship(to: star.feed)
    }
    
    func setIdentityText(identity: String) {
        self.identityLabel.text = String(identity.prefix(8))
    }

    func setRelationship(to identity: Identity) {
        if let me = Bots.current.identity {
            let relationship = Relationship(from: me, to: identity)

            relationship.load {
                self.followButton.relationship = relationship
                self.blockButton.relationship = relationship
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

class CommunityTableViewCell: UITableViewCell {

    let communityView = CommunityCellView()

    convenience init() {
        self.init(style: .default, reuseIdentifier: "CommunityTableViewCell")
        self.selectionStyle = .none
        Layout.fill(view: self.contentView, with: self.communityView)
    }

    override func prepareForReuse() {
        self.communityView.reset()
    }

    // TODO this is hack to ensure that the cells only show the
    // block button and not the follow button, the other option
    // is to push a flag through the data source, cell, and about
    // view to do the same, but that is too messy right now
    func showBlockButton() {
        self.communityView.followButton.alpha = 0
        self.communityView.blockButton.alpha = 1
    }
}
