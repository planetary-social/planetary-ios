//
//  PillButton.swift
//  Planetary
//
//  Created by Zef Houssney on 10/10/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import UIKit

// a button class with an icon on the left and a label on the right
class PillButton: AppButton {

    var height: CGFloat = 35 {
        didSet {
            self.roundedCorners(radius: self.height / 2)
            self.heightConstraint?.constant = self.height
        }
    }

    var fontSize: CGFloat = 14 {
        didSet {
            self.titleLabel?.font = UIFont.verse.pillButton.withSize(fontSize)
        }
    }
    
    private var primaryColor: UIColor
    private var secondaryColor: UIColor

    init(primaryColor: UIColor = .primaryAction, secondaryColor: UIColor = .secondaryAction) {
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
        
        super.init()

        self.useAutoLayout()

        self.titleLabel?.font = UIFont.verse.pillButton

        self.setTitleColor(secondaryColor, for: .normal)
        self.setTitleColor(UIColor.white, for: .selected)

        self.setBackgroundImage(UIColor.clear.image(), for: .normal)
        self.setBackgroundImage(primaryColor.image(), for: .selected)
        
        self.layer.borderWidth = 1.5

        self.constrainHeight(to: self.height)
        self.roundedCorners(radius: self.height / 2)

        // sets default insets
        setImage(nil)

        self.adjustsImageWhenHighlighted = false
    }
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        if isSelected {
            self.layer.borderColor = self.primaryColor.cgColor
        } else {
            self.layer.borderColor = self.secondaryColor.cgColor
        }
    }

    func setTitle(_ normal: Text, selected: Text? = nil) {
        self.setTitle(normal.text, for: .normal)
        self.setTitle(selected?.text, for: .selected)
    }

    func setImage(_ normal: UIImage?, selected: UIImage? = nil) {
        self.setImage(normal, for: .normal)
        self.setImage(selected, for: .selected)

        if normal == nil {
            self.titleEdgeInsets = .zero
            self.contentEdgeInsets = .pillButton
        } else {
            self.titleEdgeInsets = UIEdgeInsets(top: 0, left: 7, bottom: 0, right: 0)
            self.contentEdgeInsets = UIEdgeInsets(top: 0, left: 9, bottom: 0, right: 11)
        }
    }

    override var intrinsicContentSize: CGSize {
        let labelWidth = self.titleLabel?.intrinsicContentSize.width ?? 0
        // for some reason this returns -1 when there is no image set. Using min to set to 0
        let iconWidth = max(self.imageView?.intrinsicContentSize.width ?? 0, 0)
        let totalWidth = self.contentEdgeInsets.left + iconWidth + self.titleEdgeInsets.left + labelWidth + self.titleEdgeInsets.right + self.contentEdgeInsets.right
        return CGSize(width: ceil(totalWidth), height: self.height)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
