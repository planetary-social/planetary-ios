//
//  AboutCellView.swift
//  FBTT
//
//  Created by Christoph on 5/3/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

class AboutCellView: UIView {

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

        Layout.fillLeft(of: self,
                        with: self.imageView,
                        insets: UIEdgeInsets(top: verticalMargin, left: Layout.horizontalSpacing, bottom: -verticalMargin, right: 0),
                        respectSafeArea: false)

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

    func update(with identity: Identity, about: About?) {
        if let about = about {
            self.label.text = about.nameOrIdentity
            self.imageView.set(image: about.image)
        } else {
            self.label.text = identity
        }
        self.setIdentityText(identity: identity)
        self.setRelationship(to: identity)
    }

    func update(with person: Person, useRelationship: Bool = true) {
        self.label.text = person.name
        self.setIdentityText(identity: person.identity)

        self.loadImage(for: person)

        // note that the relationship will change the Follow
        // button visiblity, and is async so the button may
        // appear in the wrong initial state if scrolling quickly
        if useRelationship {
            self.setRelationship(to: person.identity)
        }
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

class AboutTableViewCell: UITableViewCell {

    let aboutView = AboutCellView()

    convenience init() {
        self.init(style: .default, reuseIdentifier: "AboutTableCellView")
        self.selectionStyle = .none
        Layout.fill(view: self.contentView, with: self.aboutView)
    }

    override func prepareForReuse() {
        self.aboutView.reset()
    }

    // TODO this is hack to ensure that the cells only show the
    // block button and not the follow button, the other option
    // is to push a flag through the data source, cell, and about
    // view to do the same, but that is too messy right now
    func showBlockButton() {
        self.aboutView.followButton.alpha = 0
        self.aboutView.blockButton.alpha = 1
    }
}

class MiniAboutCellView: UIView {

    static let height: CGFloat = 41

    let imageView = AvatarImageView()

    let nameLabel: UILabel = {
        let label = UILabel.forAutoLayout()
        label.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        return label
    }()

    let shortcodeLabel: UILabel = {
        let label = UILabel.forAutoLayout()
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        label.textAlignment = .right
        label.textColor = UIColor.text.detail
        return label
    }()

    init() {
        super.init(frame: .zero)
        self.backgroundColor = .appBackground

        self.addSubview(self.imageView)
        self.imageView.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
        self.imageView.leftAnchor.constraint(equalTo: self.leftAnchor, constant: 18).isActive = true
        self.imageView.constrainSize(to: 25)

        self.addSubview(self.nameLabel)
        self.nameLabel.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
        self.nameLabel.leftAnchor.constraint(equalTo: self.leftAnchor, constant: 54).isActive = true
        self.nameLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        self.nameLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        self.addSubview(self.shortcodeLabel)
        self.shortcodeLabel.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
        self.shortcodeLabel.pinRightToSuperview(constant: -23)
        self.shortcodeLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        self.shortcodeLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        // this will let the name label grow and shrink the code label
        // when both are really long the code label should be hidden
        self.nameLabel.constrainTrailing(toLeadingOf: self.shortcodeLabel, constant: 8)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func reset() {
        self.update(with: About())
    }
    
    func update(with about: About) {
        self.imageView.set(image: about.image)
        self.nameLabel.text = about.nameOrIdentity
        self.shortcodeLabel.text = about.shortcode
    }
}
