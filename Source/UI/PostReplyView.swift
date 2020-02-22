//
//  PostReplyView.swift
//  FBTT
//
//  Created by Christoph on 7/4/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

/// Composite view of the PostCellView, a ReplyTextView, and a bottom separator.
class PostReplyView: KeyValueView {

    let postView = PostCellView()

    let repliesView = RepliesView()

    // In this case the view is mostly used a big button to
    // navigate into a thread and start replying.  The tap
    // gesture that comes with the KeyValueView is applied
    // to the whole view, and the button and text view are
    // disabled.
    let replyTextView: ReplyTextView = {
        let view = ReplyTextView(topSpacing: 0, bottomSpacing: Layout.verticalSpacing)
        view.button.isUserInteractionEnabled = false
        view.textView.isUserInteractionEnabled = false
        view.topSeparator.isHidden = true
        view.addGestureRecognizer(view.tapGesture.recognizer)
        return view
    }()

    init() {
        super.init(frame: .zero)
        self.backgroundColor = UIColor.background.default
        self.clipsToBounds = true

        let topBorder = Layout.separatorView()
        let bottomBorder = Layout.separatorView()
        let bottomSeparator = Layout.separatorView(height: 10,
                                                   color: UIColor.background.table)

        Layout.fillTop(of: self, with: topBorder)
        Layout.fillSouth(of: topBorder, with: self.postView)
        Layout.fillSouth(of: self.postView, with: self.repliesView)
        Layout.fillSouth(of: self.repliesView, with: self.replyTextView)
        Layout.fillSouth(of: self.replyTextView, with: bottomBorder)
        Layout.fillSouth(of: bottomBorder, with: bottomSeparator)
        bottomSeparator.pinBottomToSuperviewBottom()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func update(with keyValue: KeyValue) {
        self.postView.update(with: keyValue)
        self.repliesView.update(with: keyValue)
    }
}

extension PostReplyView {

    /// Returns a CGFloat suitable to be used as a `UITableView.estimatedRowHeight` or
    /// `UITableViewDelegate.estimatedRowHeightAtIndexPath()`.  If the specified
    /// `KeyValue` has images, height for the `GalleryView` is included.  If there are replies
    /// height for the `RepliesView` is added.  This does require some knowledge of the heights
    /// for the various subviews, but this needs to be a very fast call so no complicated calculations
    /// should be done.  Instead, some magic numbers are used based on the various constraints.
    static func estimatedHeight(with keyValue: KeyValue,
                                in superview: UIView) -> CGFloat
    {
        // starting height based for all non-zero height subviews
        // header + text + reply box
        var height = CGFloat(300)
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

class RepliesView: KeyValueView {


    private let textFont = UIFont.systemFont(ofSize: 14, weight: .regular)
    private let nameFont = UIFont.systemFont(ofSize: 14, weight: .medium)

    let avatarImageView = AvatarStackView()

    var expandedHeight: CGFloat {
        return self.avatarImageView.height + Layout.verticalSpacing
    }

    let label = UILabel.forAutoLayout()

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.addGestureRecognizer(self.tapGesture.recognizer)
        self.label.constrainHeight(to: self.avatarImageView.height)

        Layout.fillTopLeft(of: self, with: self.avatarImageView, insets: .left(Layout.horizontalSpacing))
        Layout.fillTopRight(of: self, with: self.label, insets: .right(Layout.horizontalSpacing))

        self.label.constrainLeading(toTrailingOf: self.avatarImageView, constant: Layout.horizontalSpacing)

        // creates a height constraint, which we can access as heightConstraint through the UIView extension that adds it
        self.constrainHeight(to: 0)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: KeyValueUpdateable

    override func update(with keyValue: KeyValue) {
        let uniqueAbouts = Array(Set(keyValue.metadata.replies.abouts))

        self.avatarImageView.abouts = uniqueAbouts

        if !uniqueAbouts.isEmpty {
            self.updateLabel(from: uniqueAbouts)
        }

        self.heightConstraint?.constant = uniqueAbouts.isEmpty ? 0 : self.expandedHeight
    }

    private func updateLabel(from abouts: [About]) {
        let count = abouts.count
        if count == 1 {
            let text = NSMutableAttributedString(Text.oneReplyFrom.text, font: self.textFont)
            if let name = abouts.first?.name {
                text.append(NSAttributedString(name, font: self.nameFont))
            } else {
                text.append(NSAttributedString(string: Text.oneOther.text))
            }
            text.addColorAttribute(UIColor.text.default)
            self.label.attributedText = text
        } else {
            let text = NSMutableAttributedString(Text.repliesBy.text, font: self.textFont)
            if let name = abouts.first?.name {
                text.append(NSAttributedString(name, font: self.nameFont))
                let others = count > 2 ? Text.andCountOthers : Text.andOneOther
                text.append(NSAttributedString(others.text(["count": String(count - 1)]), font: self.textFont))
            } else {
                text.append(NSAttributedString(Text.countOthers.text, font: self.textFont))
            }
            text.addColorAttribute(UIColor.text.default)
            self.label.attributedText = text
        }
    }
}
