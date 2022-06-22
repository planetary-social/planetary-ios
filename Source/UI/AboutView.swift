//
//  AboutView.swift
//  FBTT
//
//  Created by Christoph on 4/18/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

class AboutView: KeyValueView {

    private let circleView: UIView = {
        let view = UIView.forAutoLayout()
        view.stroke(color: UIColor.avatarRing)
        return view
    }()

    let imageView = AvatarImageView()

    private let nameLabel: UILabel = {
        let label = UILabel.forAutoLayout()
        label.font = UIFont.boldSystemFont(ofSize: 18)
        label.lineBreakMode = .byCharWrapping
        label.numberOfLines = 2
        label.textAlignment = .center
        return label
    }()

    private let followingLabel: UILabel = {
        let label = UILabel.forAutoLayout()
        label.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        label.numberOfLines = 0
        label.textAlignment = .center
        label.textColor = UIColor.text.default
        return label
    }()

    lazy var followButton: FollowButton = {
        let button = FollowButton()
        return button
    }()

    lazy var editButton: PillButton = {
        let button = PillButton()
        button.isHidden = true
        button.setTitle(.editProfile)
        button.setImage(UIImage.verse.editPencil)
        button.isSelected = true
        
        return button
    }()

    lazy var shareButton: PillButton = {
        let button = PillButton()
        button.setTitle(.share)
        button.setImage(UIImage.verse.smallShare)
        return button
    }()

    lazy var editPhotoButton: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = .avatarRing
        button.isHidden = true
        button.setImage(UIImage.verse.camera, for: .normal)
        button.stroke(color: .avatarRing)
        return button
    }()

    var descriptionContainerZeroHeightConstraint: NSLayoutConstraint?

    private lazy var descriptionTextView: UITextView = {
        let view = UITextView.forAutoLayout()
        view.addGestureRecognizer(self.tapGesture.recognizer)
        view.isEditable = false
        view.isScrollEnabled = false
        view.textContainer.lineFragmentPadding = 0
        view.backgroundColor = .cardBackground
        return view
    }()

    var followingView = FollowCountView(text: .followingCount, secondaryText: .inYourNetwork)
    var followedByView = FollowCountView(text: .followedByCount, secondaryText: .inYourNetwork)

    // MARK: Lifecycle

    init() {
        super.init(frame: CGRect.zero)
        self.useAutoLayout()
        self.backgroundColor = .cardBackground
        self.addSubviews()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Layout

    private func addSubviews() {

        Layout.addSeparator(toTopOf: self)
        
        Layout.center(self.circleView, atTopOf: self, inset: 23, size: CGSize(square: Layout.profileImageOutside))
       // self.addLoadingAnimation()

        Layout.center(self.imageView, in: self.circleView, size: CGSize(square: Layout.profileImageInside))

        self.addSubview(self.editPhotoButton)
        self.editPhotoButton.constrainSize(to: CGSize(square: 45))
        self.editPhotoButton.constrainTop(toTopOf: self.circleView, constant: 120)
        self.editPhotoButton.constrainLeading(to: self.circleView, constant: 140)

        var insets = UIEdgeInsets.topLeftRight
        insets.top = insets.top - 2
        Layout.fillSouth(of: self.circleView, with: self.nameLabel, insets: insets)

        Layout.fillSouth(of: self.nameLabel, with: self.followingLabel, insets: .leftBottomRight)

        let buttonStack = UIStackView.forAutoLayout()
        buttonStack.spacing = Layout.horizontalSpacing
        buttonStack.distribution = .equalCentering

        buttonStack.addArrangedSubview(UIView())
        buttonStack.addArrangedSubview(self.editButton)
        buttonStack.addArrangedSubview(self.followButton)
        buttonStack.addArrangedSubview(self.shareButton)
        buttonStack.addArrangedSubview(UIView())

        Layout.fillSouth(of: self.followingLabel, with: buttonStack, insets: .top(Layout.verticalSpacing - 3))

        var separator = Layout.sectionSeparatorView(color: .appBackground)
        Layout.fillSouth(of: buttonStack, with: separator, insets: .top(Layout.verticalSpacing - 3))

        let descriptionContainer = UIView.forAutoLayout()
        descriptionContainer.clipsToBounds = true
        let verticalInset = Layout.verticalSpacing - 10
        insets = UIEdgeInsets(top: verticalInset, left: Layout.postSideMargins, bottom: -verticalInset, right: -Layout.postSideMargins)
        Layout.fill(view: descriptionContainer, with: self.descriptionTextView, insets: insets)
        Layout.addSeparator(toBottomOf: descriptionContainer)

        Layout.fillSouth(of: separator, with: descriptionContainer)

        self.descriptionContainerZeroHeightConstraint = descriptionContainer.constrainHeight(to: 0)

        Layout.fillSouth(of: descriptionContainer, with: self.followedByView)
        self.followedByView.constrainHeight(to: 50)

        separator = Layout.addSeparator(southOf: self.followedByView)

        Layout.fillSouth(of: separator, with: self.followingView)
        self.followingView.constrainHeight(to: 50)

        separator = Layout.sectionSeparatorView(bottom: false,
                                                color: .appBackground)
        Layout.fillSouth(of: self.followingView, with: separator)
        separator.pinBottomToSuperviewBottom()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.circleView.round()
        self.editPhotoButton.round()
    }

    // MARK: KeyValueUpdateable

    override func update(with keyValue: KeyValue) {
        guard let about = keyValue.value.content.about else { return }
        self.update(with: about)
    }

    // MARK: Other updates

    // called by other update functions
    private func update(name: String, bio: NSAttributedString, identity: Identity) {
        self.backgroundColor = .cardBackground

        self.nameLabel.text = name
        self.nameLabel.lineBreakMode = .byWordWrapping

        self.descriptionTextView.attributedText = bio

        self.descriptionContainerZeroHeightConstraint?.isActive = bio.string.trimmed.isEmpty
        
        self.editButton.isHidden = !identity.isCurrentUser
        self.editPhotoButton.isHidden = self.editButton.isHidden

        if identity.isCurrentUser {
            self.followingLabel.text = Text.thisIsYou.text
            self.followButton.isHidden = true
        } else {
            loadRelationship(identity: identity)
        }
        
        let communityPubs = AppConfiguration.current?.communityPubs ?? []
        if let star = communityPubs.first(where: { $0.feed == identity }) {
            followButton.star = star
        } else {
            followButton.star = nil
        }

        // updating may change the content of the description text view
        // and hence change it's height, so a layout is likely needed
        self.setNeedsLayout()
        self.layoutIfNeeded()
    }

    func update(with about: About) {

        self.update(name: about.nameOrIdentity,
                    bio: about.attributedDescription,
                    identity: about.identity)

        self.imageView.set(image: about.image)
    }

    var relationship: Relationship?

    // do this once, so we only have one notification
    private func loadRelationship(identity: Identity) {
        guard relationship == nil, let me = Bots.current.identity else { return }
        
        self.followButton.isHidden = true
        
        let relationship = Relationship(from: me, to: identity)

        relationship.load {
            self.update(with: relationship)
            self.followButton.isHidden = false
            // The follow button may re-hide itself when the relationship is set. i.e. if the relationship is
            // to oneself.
            self.followButton.relationship = relationship
        }

        NotificationCenter.default.addObserver(self, selector: #selector(relationshipDidChange(notification:)), name: relationship.notificationName, object: nil)
    }

    func update(with relationship: Relationship) {
        self.relationship = relationship

        self.followButton.isSelected = relationship.isFollowing

        if relationship.isFollowedBy {
            self.followingLabel.text = Text.isFollowingYou.text
        }
    }

    @objc func relationshipDidChange(notification: Notification) {
        guard let relationship = notification.userInfo?[Relationship.infoKey] as? Relationship else {
            return
        }
        self.update(with: relationship)
    }

    func update(followedBy: [About], following: [About]) {
        self.followedByView.abouts = followedBy
        self.followingView.abouts = following

        // updating may change the content of the following label
        // and hence change it's height, so a layout is likely needed
        self.setNeedsLayout()
        self.layoutIfNeeded()
    }
    
    // MARK: Loading animation
    
    private lazy var loadingAnimation: PeerConnectionAnimation = {
        let view = PeerConnectionAnimation(color: .networkAnimation)
        // view.multiplier = 2
        view.setDotCount(inside: false, count: 1, animated: false)
        view.setDotCount(inside: true, count: 2, animated: false)
        return view
    }()
    
    private lazy var loadingLabel: UILabel = {
        let view = UILabel.forAutoLayout()
        view.textAlignment = .center
        view.numberOfLines = 2
        view.text = Text.loadingUpdates.text
        view.textColor = UIColor.tint.default
        return view
    }()
    
    func addLoadingAnimation() {
        // Layout.center(self.loadingLabel, in: self.circleView)
        Layout.centerHorizontally(self.loadingAnimation, in: self.circleView)
        self.loadingAnimation.constrainSize(to: Layout.profileImageOutside)
        self.loadingAnimation.pinBottom(toTopOf: self.loadingLabel, constant: -20, activate: true)
    }
    
    func removeLoadingAnimation() {
        self.loadingLabel.removeFromSuperview()
        self.loadingAnimation.removeFromSuperview()
    }
}
