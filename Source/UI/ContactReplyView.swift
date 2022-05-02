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

        let bottomSeparator = Layout.separatorView(height: 10,
                                                   color: .appBackground)

        Layout.fillTop(of: self, with: topBorder)
        Layout.fillSouth(of: topBorder, with: self.contactView)
        Layout.fillSouth(of: self.contactView, with: bottomBorder)

        Layout.fillSouth(of: bottomBorder, with: self.degrade)

        Layout.fillSouth(of: degrade, with: bottomSeparator)
        bottomSeparator.pinBottomToSuperviewBottom()

        self.isSkeletonable = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func update(with keyValue: KeyValue) {
        self.contactView.update(with: keyValue)
        self.degrade.heightConstraint?.constant = 0
    }
}

extension ContactReplyView {

    /// Returns a CGFloat suitable to be used as a `UITableView.estimatedRowHeight` or
    /// `UITableViewDelegate.estimatedRowHeightAtIndexPath()`.  If the specified
    /// `KeyValue` has images, height for the `GalleryView` is included.  If there are replies
    /// height for the `RepliesView` is added.  This does require some knowledge of the heights
    /// for the various subviews, but this needs to be a very fast call so no complicated calculations
    /// should be done.  Instead, some magic numbers are used based on the various constraints.
    static func estimatedHeight(with keyValue: KeyValue,
                                in superview: UIView) -> CGFloat {
        // starting height based for all non-zero height subviews
        // header + text + reply box
        var height = CGFloat(700)
        guard let post = keyValue.value.content.post else { return height }

        // add gallery view if necessary
        // note that gallery view is square so likely the same
        // as the width of the superview
        if post.hasBlobs { height += superview.bounds.size.width }

        // add replies view if necessary
        if keyValue.metadata.replies.count > 0 { height += 35 }

        // done
        return height
    }
}
