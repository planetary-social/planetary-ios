//
//  ReplyTextView.swift
//  FBTT
//
//  Created by Christoph on 6/27/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

class ReplyTextView: KeyValueView {

    // The max height of the view is based on the max number
    // of lines the text view should have before scrolling.
    static let maxNumberOfLines: Int = 4

    let topSeparator = Layout.separatorView()

    let button = AvatarButton()

    var textViewDelegate: MentionTextViewDelegate? {
        didSet {
            self.textView.delegate = self.textViewDelegate
            self.textViewDelegate?.styleTextView(textView: self.textView)
        }
    }

    // TODO read only?
    lazy var textView: ResizableTextView = {
        let view = ResizableTextView()
        view.configureForPostsAndReplies()
        view.roundedCorners(radius: Layout.profileThumbSize / 2)
        view.backgroundColor = UIColor.background.reply
        view.isScrollEnabled = true
        view.textContainerInset = UIEdgeInsets(top: 8, left: 13, bottom: 6, right: 13)

        // this styling is redundant, but needed for when the view is used with no delegate. Could be refactored
        view.font = UIFont.verse.reply
        view.text = Text.postAReply.text
        view.textColor = UIColor.text.placeholder
        return view
    }()

    var isEmpty: Bool {
        return self.textView.text?.isEmpty ?? true
    }

    var textViewHeightConstraint: NSLayoutConstraint?

    convenience init() {
        self.init(topSpacing: Layout.verticalSpacing, bottomSpacing: Layout.verticalSpacing)
    }

    convenience init(topSpacing: CGFloat, bottomSpacing: CGFloat) {

        self.init(frame: .zero)
        self.backgroundColor = UIColor.background.default
        self.useAutoLayout()

        let textViewHeight = Layout.profileThumbSize

        Layout.fillBottomLeft(of: self, with: self.button,
                              insets: UIEdgeInsets(top: 0, left: Layout.horizontalSpacing, bottom: -bottomSpacing, right: 0),
                              respectSafeArea: false)
        self.button.constrainSize(to: textViewHeight)


        let left: CGFloat = Layout.horizontalSpacing + textViewHeight + 7
        let insets = UIEdgeInsets(top: topSpacing, left: left, bottom: -bottomSpacing, right: -Layout.horizontalSpacing)
        Layout.fill(view: self, with: self.textView, insets: insets, respectSafeArea: false)

        self.textView.constrainHeight(greaterThanOrEqualTo: textViewHeight)
        self.textViewHeightConstraint = self.textView.heightAnchor.constraint(lessThanOrEqualToConstant: textViewHeight)
        self.textViewHeightConstraint?.isActive = true
        self.calculateHeight()

        self.button.setImageForMe()
    }

    func calculateHeight() {
        let lineHeight = self.textView.font?.lineHeight ?? 18
        let sizeToFit = CGSize(width: self.textView.bounds.width, height: CGFloat.greatestFiniteMagnitude)
        let textSize = self.textView.sizeThatFits(sizeToFit)
        let maxLines = Int(textSize.height / lineHeight)
        let lineCount = min(ReplyTextView.maxNumberOfLines, max(maxLines, 1))

        let insets = self.textView.textContainerInset
        let maxHeight = ceil(insets.top + insets.bottom + (lineHeight * CGFloat(lineCount)))
        let defaultHeight = Layout.profileThumbSize

        self.textViewHeightConstraint?.constant = max(defaultHeight, maxHeight)
        self.textView.allowScrolling = maxLines > lineCount
    }

    @discardableResult
    override func resignFirstResponder() -> Bool {
        self.textView.resignFirstResponder()
        return super.resignFirstResponder()
    }

    func clear() {
        self.textView.text = Text.postAReply.text
        self.textView.textColor = UIColor.text.placeholder
        self.calculateHeight()
    }
}

// this exists to prevent an odd jumping behavior where the contentOffset is changed when the text view is expanded.
// when a textView expands upwards, the contentOffset is adjusted in an undesirable way,
// To avoid this, we can pin it to 0 whenever the lines are fewer than the max allowed
class ResizableTextView: UITextView {

    // When allowScrolling is false, we pin the contentOffset.y to 0, which prevents the undesired jumping behavior.
    // When we get to a place where we want to allow scrolling, like the text field being tall enough and no longer growing
    // we change this value to true, and scrolling can be performed normally
    var allowScrolling = false

    override var contentOffset: CGPoint {
        didSet {
            if !allowScrolling, self.contentOffset.y != 0 {
                self.contentOffset.y = 0
            }
        }
    }
}
