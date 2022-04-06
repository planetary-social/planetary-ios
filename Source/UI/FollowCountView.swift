//
//  FollowCountView.swift
//  Planetary
//
//  Created by Zef Houssney on 10/25/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import UIKit

class FollowCountView: UIView {

    var abouts: [About] = [] {
        didSet {
            self.load()
        }
    }

    var action: () -> Void = {}

    let text: Text
    let secondaryText: Text
    let avatarView = AvatarStackView()

    let label: UILabel = {
        let view = UILabel.forAutoLayout()
        view.font = UIFont.verse.followCountView
        view.textAlignment = .left
        view.textColor = UIColor.secondaryText
        return view
    }()

    init(text: Text, secondaryText: Text) {
        self.text = text
        self.secondaryText = secondaryText

        super.init(frame: CGRect.zero)
        self.useAutoLayout()

        Layout.fillLeft(of: self, with: self.avatarView, insets: .topLeftBottom)

        let chevron = UIImageView(image: UIImage.verse.cellChevron)
        chevron.useAutoLayout()
        self.addSubview(chevron)
        chevron.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
        chevron.pinRightToSuperview(constant: -Layout.horizontalSpacing)

        self.addSubview(self.label)
        self.label.constrainLeading(toTrailingOf: self.avatarView, constant: Layout.horizontalSpacing)
        self.label.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true

        let tap = UITapGestureRecognizer(target: self, action: #selector(self.didTap(_:)))
        self.addGestureRecognizer(tap)
    }

    func load() {
        self.avatarView.abouts = self.abouts
        let count = String(self.abouts.count)
        let string = self.text.text(["count": count])
        let attributed = NSMutableAttributedString(string: string)
        let range = (string as NSString).range(of: string)
        attributed.addAttribute(.foregroundColor, value: UIColor.mainText, range: range)
        attributed.append(NSAttributedString(string: self.secondaryText.text))
        self.label.attributedText = attributed
    }

    @objc func didTap(_ sender: UITapGestureRecognizer? = nil) {
        action()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
