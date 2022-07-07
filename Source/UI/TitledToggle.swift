//
//  TitledToggle.swift
//  FBTT
//
//  Created by Christoph on 7/18/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

class TitledToggle: UIView {

    let titleLabel: UILabel = {
        let view = UILabel.forAutoLayout()
        view.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        view.lineBreakMode = .byWordWrapping
        view.numberOfLines = 0
        view.textColor = UIColor.text.default
        return view
    }()

    let subtitleLabel: UILabel = {
        let view = UILabel.forAutoLayout()
        view.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        view.lineBreakMode = .byWordWrapping
        view.numberOfLines = 0
        view.textColor = UIColor.text.detail
        return view
    }()

    let toggle = UISwitch.default()

    override init(frame: CGRect) {
        super.init(frame: frame)

        Layout.addSeparator(toTopOf: self)

        let insets = UIEdgeInsets(top: 14, left: 20, bottom: 12, right: 18)
        Layout.fillTopRight(of: self, with: self.toggle, insets: insets)
        self.toggle.pinRightToSuperview(constant: insets.right)

        Layout.fillTopLeft(of: self, with: self.titleLabel, insets: insets)
        self.titleLabel.rightAnchor.constraint(equalTo: self.toggle.leftAnchor, constant: -10).isActive = true
        self.titleLabel.constrainHeight(to: self.toggle)

        Layout.fillBottomLeft(of: self, with: self.subtitleLabel, insets: insets)
        self.subtitleLabel.pinTop(toBottomOf: self.toggle, constant: 4)
        self.subtitleLabel.constrainWidth(to: self.titleLabel)

        Layout.addSeparator(toBottomOf: self)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
