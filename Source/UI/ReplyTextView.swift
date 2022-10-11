//
//  ReplyTextView.swift
//  FBTT
//
//  Created by Christoph on 6/27/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit
import Combine

class ReplyTextView: MessageUIView {

    // The max height of the view is based on the max number
    // of lines the text view should have before scrolling.
    static let maxNumberOfLines: Int = 4

    let topSeparator = Layout.separatorView()

    let button = AvatarButton()
    
    var attributedText: NSAttributedString {
        get {
            sourceTextView.attributedText
        }

        set {
            sourceTextView.attributedText = newValue
        }
    }

    var textViewDelegate: MentionTextViewDelegate? {
        didSet {
            self.sourceTextView.delegate = self.textViewDelegate
            self.textViewDelegate?.styleTextView(textView: self.sourceTextView)
        }
    }
    
    var textPublisher: AnyPublisher<NSAttributedString?, Never> = Just(nil).eraseToAnyPublisher()

    var previewActive: Bool {
        get {
            renderedTextView.alpha > 0.9
        }

        set {
            if newValue {
                sourceTextView.isEditable = false
                renderedTextView.attributedText = sourceTextView.attributedText.string.decodeMarkdown()
                animateToPreview()
            } else {
                sourceTextView.isEditable = true
                renderedTextView.attributedText = nil
                animateToSourceView()
            }
        }
    }
    
    private lazy var sourceTextView: ResizableTextView = {
        let view = ResizableTextView()
        view.configureForPostsAndReplies()
        view.roundedCorners(radius: Layout.profileThumbSize / 2)
        view.backgroundColor = UIColor.textInputBackground
        view.isScrollEnabled = true
        view.textContainerInset = UIEdgeInsets(top: 8, left: 13, bottom: 6, right: 13)

        // this styling is redundant, but needed for when the view is used with no delegate. Could be refactored
        view.font = UIFont.verse.reply
        view.text = Localized.postAReply.text
        view.textColor = UIColor.text.placeholder
        view.layer.borderWidth = 1 / UIScreen.main.scale
        view.layer.borderColor = UIColor.textInputBorder.cgColor
        return view
    }()
    
    private lazy var renderedTextView: UITextView = {
        let view = UITextView.forPostsAndReplies()
        view.backgroundColor = .cardBackground
        view.textColor = UIColor.text.default
        view.alpha = 0
        view.isEditable = false
        return view
    }()

    var isEmpty: Bool {
        self.sourceTextView.text?.isEmpty ?? true
    }

    var textViewHeightConstraint: NSLayoutConstraint?

    convenience init() {
        self.init(topSpacing: Layout.verticalSpacing, bottomSpacing: Layout.verticalSpacing)
    }

    convenience init(topSpacing: CGFloat, bottomSpacing: CGFloat) {

        self.init(frame: .zero)
        self.backgroundColor = .appBackground
        self.useAutoLayout()
        self.clipsToBounds = false
        
        textPublisher = NotificationCenter.default
            .publisher(for: UITextView.textDidChangeNotification, object: sourceTextView)
            .map { ($0.object as? UITextView)?.attributedText }
            .eraseToAnyPublisher()

        let textViewHeight = Layout.profileThumbSize

        Layout.fillBottomLeft(of: self, with: self.button,
                              insets: UIEdgeInsets(top: 0, left: Layout.horizontalSpacing, bottom: -bottomSpacing, right: 0),
                              respectSafeArea: false)
        self.button.constrainSize(to: textViewHeight)

        let left: CGFloat = Layout.horizontalSpacing + textViewHeight + 7
        let insets = UIEdgeInsets(top: topSpacing, left: left, bottom: -bottomSpacing, right: -Layout.horizontalSpacing)
        Layout.fill(view: self, with: self.sourceTextView, insets: insets, respectSafeArea: false)

        self.sourceTextView.constrainHeight(greaterThanOrEqualTo: textViewHeight)
        self.textViewHeightConstraint = self.sourceTextView.heightAnchor.constraint(lessThanOrEqualToConstant: textViewHeight)
        self.textViewHeightConstraint?.isActive = true
        self.calculateHeight()
        
        addSubview(renderedTextView)
        renderedTextView.topAnchor.constraint(equalTo: sourceTextView.topAnchor,
                                              constant: 0).isActive = true
        renderedTextView.leftAnchor.constraint(equalTo: sourceTextView.leftAnchor,
                                               constant: 0).isActive = true
        renderedTextView.bottomAnchor.constraint(equalTo: sourceTextView.bottomAnchor,
                                                 constant: 0).isActive = true
        renderedTextView.rightAnchor.constraint(equalTo: sourceTextView.rightAnchor,
                                                constant: 0).isActive = true
        
        self.button.setImageForMe()
        
        self.button.isSkeletonable = true
        self.sourceTextView.isSkeletonable = true
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        self.sourceTextView.layer.borderColor = UIColor.textInputBorder.cgColor
        self.renderedTextView.layer.borderColor = UIColor.textInputBorder.cgColor
        self.sourceTextView.setNeedsDisplay()
        self.renderedTextView.setNeedsDisplay()
    }
    
    func calculateHeight() {
        let lineHeight = self.sourceTextView.font?.lineHeight ?? 18
        let sizeToFit = CGSize(width: self.sourceTextView.bounds.width, height: CGFloat.greatestFiniteMagnitude)
        let textSize = self.sourceTextView.sizeThatFits(sizeToFit)
        let maxLines = Int(textSize.height / lineHeight)
        let lineCount = min(ReplyTextView.maxNumberOfLines, max(maxLines, 1))

        let insets = self.sourceTextView.textContainerInset
        let maxHeight = ceil(insets.top + insets.bottom + (lineHeight * CGFloat(lineCount)))
        let defaultHeight = Layout.profileThumbSize

        self.textViewHeightConstraint?.constant = max(defaultHeight, maxHeight)
        self.sourceTextView.allowScrolling = maxLines > lineCount
    }

    @discardableResult
    override func becomeFirstResponder() -> Bool {
        self.sourceTextView.becomeFirstResponder()
    }
    
    @discardableResult
    override func resignFirstResponder() -> Bool {
        self.sourceTextView.resignFirstResponder()
        return super.resignFirstResponder()
    }
    
    override var isUserInteractionEnabled: Bool {
        get {
            self.sourceTextView.isUserInteractionEnabled
        }
        set {
            self.sourceTextView.isUserInteractionEnabled = newValue
        }
    }
    
    func replaceText(in range: NSRange, with mention: Mention, attributes: [NSAttributedString.Key: Any]? = nil) {
        self.sourceTextView.replaceText(in: range, with: mention, attributes: attributes)
    }

    func clear() {
        self.sourceTextView.text = Localized.postAReply.text
        self.sourceTextView.textColor = UIColor.text.placeholder
        self.renderedTextView.alpha = 0
        self.sourceTextView.alpha = 1
        self.calculateHeight()
    }
    
    private func animateToPreview() {
        UIView.animate(withDuration: 0.25, animations: {
            self.sourceTextView.alpha = 0
        },
        completion: { (_) in
            UIView.animate(withDuration: 0.25) {
                self.renderedTextView.alpha = 1
            }
        })
    }

    private func animateToSourceView() {
        UIView.animate(withDuration: 0.25, animations: {
            self.renderedTextView.alpha = 0
        },
        completion: { (_) in
            UIView.animate(withDuration: 0.25) {
                self.sourceTextView.alpha = 1
            }
        })
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
