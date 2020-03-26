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

    let postButton: PillButton = {
        let button = PillButton()
        button.setTitle(.post)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        button.isSelected = true
        button.height = 32
        return button
    }()

    // MARK: Lifecycle

    convenience init() {

        self.init(frame: .zero)
        self.useAutoLayout()
        self.backgroundColor = UIColor.background.default

        Layout.fillTop(of: self, with: self.topSeparator)

        let size = CGSize(square: 44)
        self.addSubview(self.photoButton)
        self.photoButton.pinLeftToSuperview(constant: Layout.horizontalSpacing)
        self.photoButton.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
        self.photoButton.constrainSize(to: size)

        self.addSubview(self.postButton)
        self.postButton.pinRightToSuperview(constant: -Layout.horizontalSpacing)
        self.postButton.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
    }

    // MARK: Animations

    func minimize(duration: TimeInterval = 0) {
        UIView.animate(withDuration: duration) {
            self.photoButton.alpha = 0
            self.postButton.alpha = 0
            self.heightConstraint?.constant = 0
        }
    }

    func maximize(duration: TimeInterval = 0) {
        UIView.animate(withDuration: duration) {
            self.photoButton.alpha = 1
            self.postButton.alpha = 1
            self.heightConstraint?.constant = Self.viewHeight
        }
    }
}
