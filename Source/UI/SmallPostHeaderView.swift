//
//  SmallPostHeaderView.swift
//  Planetary
//
//  Created by Martin Dutra on 6/17/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import UIKit
import Analytics

class SmallPostHeaderView: UIView {

    private var identity: Identity?

    private lazy var avatarButton: AvatarButton = {
        let button = AvatarButton()
        button.addTarget(self, action: #selector(didTapAvatarButton), for: .touchUpInside)
        button.isSkeletonable = true
        return button
    }()

    private lazy var nameButton: UIButton = {
        let button = UIButton(type: .custom).useAutoLayout()
        button.addTarget(self, action: #selector(didTapAvatarButton), for: .touchUpInside)
        button.setTitleColor(.secondaryText, for: .normal)
        button.contentHorizontalAlignment = .left
        button.titleLabel?.font = UIFont.smallPost.bigHeading
        button.titleLabel?.lineBreakMode = .byTruncatingTail
        button.titleLabel?.numberOfLines = 1
        button.clipsToBounds = true
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

        Layout.fillLeft(
            of: self,
            with: self.avatarButton,
            insets: UIEdgeInsets(top: 10, left: 10, bottom: -10, right: 0),
            respectSafeArea: false
        )
        self.avatarButton.constrainSize(to: 20)

        self.addSubview(self.nameButton)
        self.nameButton.constrainTop(toTopOf: self.avatarButton)
        self.nameButton.constrainLeading(toTrailingOf: self.avatarButton, constant: 5)
        self.nameButton.constrainTrailingToSuperview(constant: -10)
        nameButton.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        nameButton.titleLabel?.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        self.nameButton.constrainHeight(to: 20)
    }

    required init?(coder aDecoder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.avatarButton.round()
    }

    func update(with keyValue: KeyValue) {
        let identity = keyValue.value.author
        self.identity = identity

        let about = keyValue.metadata.author.about
        let name = about?.nameOrIdentity ?? keyValue.value.author
        self.nameButton.setTitle(name, for: .normal)
        self.nameButton.titleLabel?.setNeedsLayout()
        self.avatarButton.setImage(for: about)
    }

    @objc
    private func didTapAvatarButton() {
        guard let identity = self.identity else { return }
        Analytics.shared.trackDidTapButton(buttonName: "avatar")
        AppController.shared.pushViewController(for: .about, with: identity)
    }
}
