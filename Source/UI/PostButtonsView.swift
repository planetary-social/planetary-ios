//
//  PostButtonsView.swift
//  FBTT
//
//  Created by Christoph on 7/1/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

class PostButtonsView: UIView {

    static let viewHeight: CGFloat = 50

    let topSeparator = Layout.separatorView()

    let photoButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(UIImage.verse.newPostOpenLibrary, for: .normal)
        return button
    }()
    
    let markdownNoticeLabel: UILabel = {
        let label = UILabel.forAutoLayout()
        label.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        label.textColor = UIColor.text.detail
        label.text = Localized.markdownSupported.text
        return label
    }()

    let previewToggle: UISwitch = {
        let toggle = UISwitch()
        toggle.translatesAutoresizingMaskIntoConstraints = false
        toggle.tintColor = UIColor.tint.default
        toggle.onTintColor = UIColor.tint.default
        return toggle
    }()

    let postButton: PillButton = {
        let button = PillButton()
        button.setTitle(.postAction)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        button.isSelected = true
        button.height = 32
        return button
    }()

    // MARK: Lifecycle

    convenience init() {

        self.init(frame: .zero)
        self.useAutoLayout()
        self.backgroundColor = .appBackground

        Layout.fillTop(of: self, with: self.topSeparator)

        let size = CGSize(square: 44)
        self.addSubview(self.photoButton)
        self.photoButton.pinLeftToSuperview(constant: Layout.horizontalSpacing)
        self.photoButton.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
        self.photoButton.constrainSize(to: size)

        self.addSubview(self.postButton)
        self.postButton.pinRightToSuperview(constant: -Layout.horizontalSpacing)
        self.postButton.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true

        self.addSubview(self.previewToggle)
        self.previewToggle.trailingAnchor.constraint(equalTo: self.postButton.leadingAnchor,
                                                     constant: -Layout.horizontalSpacing).isActive = true
        self.previewToggle.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true

        self.addSubview(self.markdownNoticeLabel)
        self.markdownNoticeLabel.trailingAnchor.constraint(equalTo: self.previewToggle.leadingAnchor,
                                                           constant: -Layout.horizontalSpacing).isActive = true
        self.markdownNoticeLabel.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
    }

    // MARK: Animations

    func minimize(duration: TimeInterval = 0) {
        UIView.animate(withDuration: duration) {
            self.photoButton.alpha = 0
            self.postButton.alpha = 0
            self.previewToggle.alpha = 0
            self.markdownNoticeLabel.alpha = 0
            self.heightConstraint?.constant = 0
        }
    }

    func maximize(duration: TimeInterval = 0) {
        UIView.animate(withDuration: duration) {
            self.photoButton.alpha = 1
            self.postButton.alpha = 1
            self.previewToggle.alpha = 1
            self.markdownNoticeLabel.alpha = 1
            self.heightConstraint?.constant = Self.viewHeight
        }
    }
}
