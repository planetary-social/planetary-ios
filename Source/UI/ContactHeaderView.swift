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

        Layout.fillLeft(of: self, with: self.identityButton, respectSafeArea: false)
        self.identityButton.constrainSize(to: Layout.contactThumbSize)

        self.addSubview(self.nameButton)
        self.nameButton.pinTopToSuperview()
        self.nameButton.constrainLeading(toTrailingOf: self.identityButton, constant: Layout.horizontalSpacing)
        self.nameButton.constrainTrailingToSuperview()

        self.nameButton.constrainHeight(to: 19)

        self.isSkeletonable = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.identityButton.round()
    }

    func update(with keyValue: KeyValue) {
        let identity = keyValue.value.author
        self.identity = identity

        let about = keyValue.metadata.author.about
        let name = about?.nameOrIdentity ?? keyValue.value.author
        let string = Text.startedFollowing.text(["somebody": name])
        let primaryColor = [NSAttributedString.Key.foregroundColor:  UIColor.text.default]
        let secondaryColor = [NSAttributedString.Key.foregroundColor:  UIColor.text.detail]
        let attributedString = NSMutableAttributedString(string: string, attributes: secondaryColor)
        let range = (string as NSString).range(of: name)
        attributedString.addAttributes(primaryColor, range: range)

        self.nameButton.setAttributedTitle(attributedString, for: .normal)
        self.identityButton.setImage(for: about)

        self.setNeedsLayout()
        self.layoutIfNeeded()
    }

    @objc private func selectAboutIdentity() {
        guard let identity = self.identity else { return }
        Analytics.shared.trackDidTapButton(buttonName: "avatar")
        AppController.shared.pushViewController(for: .about, with: identity)
    }
}
