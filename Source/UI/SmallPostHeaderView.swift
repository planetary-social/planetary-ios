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

    convenience init(with message: Message) {
        self.init()
        update(with: message)
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

    func update(with message: Message) {
        let identity = message.value.author
        self.identity = identity

        let about = message.metadata.author.about
        let name = about?.nameOrIdentity ?? message.value.author
        self.nameButton.setTitle(name, for: .normal)
        self.avatarButton.setImage(for: about)
    }

    @objc
    private func didTapAvatarButton() {
        guard let identity = self.identity else { return }
        Analytics.shared.trackDidTapButton(buttonName: "avatar")
        AppController.shared.pushViewController(for: .about, with: identity)
    }
}
