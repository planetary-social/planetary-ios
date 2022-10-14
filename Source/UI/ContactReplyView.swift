//
//  ContactReplyView.swift
//  Planetary
//
//  Created by Martin Dutra on 1/5/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

/// Composite view of the PostCellView, a ReplyTextView, and a bottom separator.
class ContactReplyView: MessageView {

    let contactView = ContactCellView()

    let degrade: UIView = {
        let backgroundView = UIView.forAutoLayout()
        backgroundView.constrainHeight(to: 0)
        let colorView = UIImageView.forAutoLayout()
        colorView.image = UIImage.thread
        colorView.contentMode = .scaleToFill
        let (_, _, bottomConstraint, _) = Layout.fill(view: backgroundView, with: colorView)
        bottomConstraint.priority = .required
        return backgroundView
    }()

    init() {
        super.init(frame: .zero)
        self.backgroundColor = .cardBackground
        self.clipsToBounds = true

        let topBorder = Layout.separatorView()
        let bottomBorder = Layout.separatorView()

        topBorder.backgroundColor = .cardBorder
        bottomBorder.backgroundColor = .cardBorder

        let bottomSeparator = Layout.separatorView(height: 10, color: .appBackground)

        Layout.fillTop(of: self, with: topBorder)
        Layout.fillSouth(of: topBorder, with: self.contactView)
        Layout.fillSouth(of: self.contactView, with: bottomBorder)

        Layout.fillSouth(of: bottomBorder, with: self.degrade)

        Layout.fillSouth(of: degrade, with: bottomSeparator)
        bottomSeparator.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true

        isSkeletonable = true
    }

    required init?(coder aDecoder: NSCoder) {
        nil
    }

    override func reset() {
        super.reset()
        self.contactView.reset()
        self.degrade.heightConstraint?.constant = 0
        setNeedsLayout()
        layoutIfNeeded()
    }

    override func update(with message: Message) {
        self.contactView.update(with: message)
        setNeedsLayout()
        layoutIfNeeded()
    }
}

extension ContactReplyView {

    /// Returns a CGFloat suitable to be used as a `UITableView.estimatedRowHeight` or
    /// `UITableViewDelegate.estimatedRowHeightAtIndexPath()`.
    static func estimatedHeight(with message: Message, in superview: UIView) -> CGFloat {
        2
    }
}
