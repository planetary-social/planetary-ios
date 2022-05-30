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
class ContactReplyView: KeyValueView {

    let contactView = ContactCellView()

    let degrade: UIView = {
        let backgroundView = UIView.forAutoLayout()
        backgroundView.constrainHeight(to: 0)
        let colorView = UIImageView.forAutoLayout()
        colorView.image = UIImage(named: "Thread")
        colorView.contentMode = .scaleToFill
        Layout.fill(view: backgroundView, with: colorView)
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
        bottomSeparator.pinBottomToSuperviewBottom()

        isSkeletonable = true
    }

    required init?(coder aDecoder: NSCoder) {
        nil
    }

    override func reset() {
        super.reset()
        self.contactView.reset()
        self.degrade.heightConstraint?.constant = 0
    }

    override func update(with keyValue: KeyValue) {
        self.contactView.update(with: keyValue)
    }
}

extension ContactReplyView {

    /// Returns a CGFloat suitable to be used as a `UITableView.estimatedRowHeight` or
    /// `UITableViewDelegate.estimatedRowHeightAtIndexPath()`.
    static func estimatedHeight(with keyValue: KeyValue, in superview: UIView) -> CGFloat {
        return CGFloat(158)
    }
}
