//
//  ContactHeaderView.swift
//  Planetary
//
//  Created by Martin Dutra on 1/5/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit
import Analytics

class ContactHeaderView: UIView {

    private var identity: Identity?

    private lazy var identityButton: AvatarButton = {
        let button = AvatarButton()
        button.addTarget(self, action: #selector(selectAboutIdentity), for: .touchUpInside)
        button.isSkeletonable = true
        return button
    }()

    private lazy var nameButton: UIButton = {
        let button = UIButton(type: .custom).useAutoLayout()
        button.addTarget(self, action: #selector(selectAboutIdentity), for: .touchUpInside)
        button.setTitleColor(UIColor.text.default, for: .normal)
        button.contentHorizontalAlignment = .left
        button.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        button.titleLabel?.lineBreakMode = .byTruncatingTail
        button.titleLabel?.numberOfLines = 1
        button.titleLabel?.linesCornerRadius = 7
        button.titleLabel?.isSkeletonable = true
        button.titleLabel?.lastLineFillPercent = 100
        button.isSkeletonable = true
        return button
    }()

    convenience init(with keyValue: KeyValue) {
        self.init()
        update(with: keyValue)
    }

    init() {
        super.init(frame: CGRect.zero)
        self.useAutoLayout()

        Layout.fillLeft(of: self, with: self.identityButton, insets: .topLeftRight, respectSafeArea: false)
        self.identityButton.constrainSize(to: Layout.contactThumbSize)

        self.addSubview(self.nameButton)
        self.nameButton.centerYAnchor.constraint(equalTo: identityButton.centerYAnchor).isActive = true
        self.nameButton.constrainLeading(toTrailingOf: self.identityButton, constant: 10)
        self.nameButton.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true

        self.nameButton.constrainHeight(to: 19)

        self.isSkeletonable = true

        reset()
    }

    required init?(coder aDecoder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        identityButton.round()
        layoutSkeletonIfNeeded()
    }

    func reset() {
        update(with: Identity.null, about: nil, text: Text.startedFollowing)
        showSkeleton()
    }

    func update(with keyValue: KeyValue) {
        let identity = keyValue.value.author
        self.identity = identity
        let about = keyValue.metadata.author.about
        var text: Text
        switch keyValue.contentType {
        case .post:
            text = .replied
        case .vote:
            text = .liked
        case .contact:
            text = .startedFollowing
        default:
            text = .startedFollowing
        }
        self.update(with: identity, about: about, text: text)
    }

    private func update(with identity: Identity, about: About?, text: Text) {
        let name = about?.nameOrIdentity ?? identity
        var string = text.text(["somebody": name])
        if identity == .null {
            string = "all above the baseline"
            // because otherwise they stick out under the skeleton
        }
        
        let primaryAttributes = [
            NSAttributedString.Key.foregroundColor: UIColor.text.default,
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: 15, weight: .semibold)
        ]
        let secondaryAttributes = [
            NSAttributedString.Key.foregroundColor: UIColor.text.detail,
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: 15, weight: .regular)
        ]
        let attributedString = NSMutableAttributedString(string: string, attributes: secondaryAttributes)
        // swiftlint:disable legacy_objc_type
        let range = (string as NSString).range(of: name)
        // swiftlint:enable legacy_objc_type
        attributedString.addAttributes(primaryAttributes, range: range)
        
        self.nameButton.setAttributedTitle(attributedString, for: .normal)
        if let about = about {
            self.identityButton.setImage(for: about)
        } else {
            identityButton.setImage(UIImage.verse.missingAbout, for: .normal)
        }

        hideSkeleton()
        self.setNeedsLayout()
        self.layoutIfNeeded()
    }

    @objc
    private func selectAboutIdentity() {
        guard let identity = self.identity else { return }
        Analytics.shared.trackDidTapButton(buttonName: "avatar")
        AppController.shared.pushViewController(for: .about, with: identity)
    }
}
