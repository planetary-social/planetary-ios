//
//  PostCellView.swift
//  FBTT
//
//  Created by Christoph on 4/18/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import ImageSlideshow
import UIKit
import SkeletonView

class PostCellView: KeyValueView {

    let verticalSpace: CGFloat = 5

    private lazy var seeMoreString: NSAttributedString = {
        let seeMore = NSMutableAttributedString(string: "... \(Text.seeMore.text)")
        let styler = MarkdownStyler()
        styler.style(seeMore: seeMore)
        let range = (seeMore.string as NSString).range(of: Text.seeMore.text)
        seeMore.addAttributes([NSAttributedString.Key.foregroundColor: UIColor.tint.default], range: range)
        return seeMore
    }()

    var displayHeader = true {
        didSet {
            self.headerContainer.isHidden = !self.displayHeader
//            self.textViewTopConstraint.constant = self.textViewTopInset
        }
    }

    var allowSpaceUnderGallery = true
    var showTimestamp: Bool

    var keyValue: KeyValue?
    
    let contentStackView: UIStackView = {
        let contentStackView = UIStackView()
        contentStackView.axis = .vertical
        contentStackView.distribution = .fill
        contentStackView.spacing = Layout.verticalSpacing
        return contentStackView
    }()
    
    private lazy var headerContainer: UIView = {
        let view = UIView.forAutoLayout()
        Layout.fill(view: view, with: headerView, insets: .topLeftRight, respectSafeArea: false)
        return view
    }()
    
    private lazy var headerView = PostHeaderView(showTimestamp: showTimestamp)
    
    private lazy var textViewContainer: UIView = {
        let view = UIView.forAutoLayout()
        Layout.fill(view: view, with: textView, insets: .leftRight, respectSafeArea: false)
        return view
    }()
    
    private lazy var textView: UILabel = {
        let view = UILabel.forAutoLayout()
        view.addGestureRecognizer(self.tapGesture.recognizer)
//        view.isEditable = false
//        view.isScrollEnabled = false
//        view.textContainer.lineFragmentPadding = 0
//        view.textContainer.lineBreakMode = .byTruncatingTail
        view.isSkeletonable = true
        view.linesCornerRadius = 30
        view.backgroundColor = .cardBackground
        view.numberOfLines = 0 // truncationLimit?.to ?? 0
        return view
    }()

//    private lazy var textView: UITextView = {
//        let view = UITextView.forAutoLayout()
//        view.addGestureRecognizer(self.tapGesture.recognizer)
//        view.isEditable = false
//        view.isScrollEnabled = false
//        view.textContainer.lineFragmentPadding = 0
//        view.textContainer.lineBreakMode = .byTruncatingTail
//        view.isSkeletonable = true
//        view.linesCornerRadius = 30
//        view.backgroundColor = .cardBackground
//        return view
//    }()

//    var textViewTopConstraint = NSLayoutConstraint()
    
    /// Activate or deactivate this constraint to make text view have no height (5px actually),
    /// for instance, if the text is empty
//    var textViewZeroHeightConstraint = NSLayoutConstraint()

    var textViewTopInset: CGFloat {
        if self.displayHeader {
            return Layout.profileThumbSize + Layout.verticalSpacing + self.verticalSpace
        } else {
            return self.verticalSpace
        }
    }

    var fullPostText = NSAttributedString() {
        didSet {
            // reset cached text, but don't recalculate yet so we don't do unnecessary work.
            self.truncationData = nil
        }
    }

    var truncationData: (text: NSAttributedString, width: CGFloat)?
    private let emptyTruncationData = (text: NSAttributedString.empty, width: CGFloat(0))

    var truncationLimit: TruncationSettings? {
        didSet {
//            if let oldValue = oldValue, let newValue = truncationLimit, newValue.to == oldValue.to, newValue.over == oldValue.over {
                // Don't recalculate truncated state
//                return
//            } else {
//                self.truncationData = nil
//                self.configureTruncatedState()
//            }
            textView.numberOfLines = 0 // truncationLimit?.to ?? 0
        }
    }

    var shouldTruncate: Bool {
        self.truncationLimit != nil
    }

    var textIsExpanded = false {
        didSet {
            self.updateFullPostText()
            self.configureTruncatedState()
        }
    }

    func toggleExpanded() {
        self.textIsExpanded = !self.textIsExpanded
    }

    private func updateFullPostText() {
//        guard self.textIsExpanded else { return }
//        guard let keyValue = self.keyValue, keyValue.value.content.isPost else { return }
//        let string = Caches.text.from(keyValue).mutable()
    }

    func configureTruncatedState() {
//        self.calculateTruncationDataIfNecessary()
        self.textView.attributedText = self.fullPostText
        
        // not so clean but it gest likes displaying.
        if self.textView.attributedText?.string.isSingleEmoji == true && self.keyValue?.value.content.type == ContentType.vote {
            self.textView.font = UIFont.post.body.withSize(16)
            self.textView.textAlignment = .natural
        } else if self.textView.attributedText?.string.isSingleEmoji == true,
            let post = self.keyValue?.value.content.post,
            !post.hasBlobs {
            self.textView.font = UIFont.post.body.withSize(100)
            self.textView.textAlignment = .center
        } else {
            self.textView.textAlignment = .natural
        }
        
        textView.isHidden = textView.attributedText?.string.isEmpty ?? true
//        self.textViewZeroHeightConstraint.isActive = self.textView.attributedText.string.isEmpty
        textView.setNeedsLayout()
        textView.layoutIfNeeded()
    }

    /// Calculates the truncation data, but only when necessary.  In some cases, an optimized
    /// answer can be used because `NSAttributedString.truncating()` is very
    /// expensive, especially during scrolling.
    func calculateTruncationDataIfNecessary() {
        return

        // skip calculation if not necessary
        guard let limit = self.truncationLimit else { return }
        guard self.truncationData == nil else { return }
        guard !self.textIsExpanded else { return }

        // truncation cannot be calculated without a height
        // so return an optimized answer to allow text layout
        guard self.textView.frame.width > 0 else {
            self.truncationData = self.emptyTruncationData
            return
        }

        // calculate with a valid width
        let width = self.textView.frame.width
        let text = fullPostText.truncating(with: self.seeMoreString, settings: limit, width: width)
        self.truncationData = (text: text, width: width)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        // this busts the cache for the truncationData,
        // which must be recalculated when the width is changed
        if let width = self.truncationData?.width, self.textView.frame.width != width {
            self.truncationData = nil
            self.configureTruncatedState()
        }
    }

    // the gallery view allows custom insets for the actual content
    // inside of it, and this value was chosen to allow for a specific
    // distance between the content top and the northern text view
    private let galleryView = GalleryView()
//    private var galleryViewZeroHeightConstraint: NSLayoutConstraint!
//    private var galleryViewFullHeightConstraint: NSLayoutConstraint!
//    private var galleryViewBottomConstraint: NSLayoutConstraint?

    // MARK: Lifecycle

    /// Initializes the view with the given parameters.
    /// - Parameter showTimestamp: Will show the claimed post time if true, author id if false.
    init(showTimestamp: Bool = false) {
        self.showTimestamp = showTimestamp
        super.init(frame: CGRect.zero)
        self.useAutoLayout()
        
        self.backgroundColor = .cardBackground
        
        Layout.fill(
            view: self,
            with: contentStackView,
            respectSafeArea: false
        )
        contentStackView.addArrangedSubview(headerContainer)
        contentStackView.addArrangedSubview(textViewContainer)
        contentStackView.addArrangedSubview(galleryView)
//
        galleryView.constrainWidth(to: self)
//        galleryView.widthAnchor.constraint(equalTo: widthAnchor).isActive = true
        galleryView.heightAnchor.constraint(equalTo: galleryView.widthAnchor).isActive = true

//        Layout.fillTop(of: self, with: self.headerView, insets: .topLeftRight)

//        let (top, _, _) = Layout.fillTop(
//            of: self,
//            with: self.textView,
//            insets: UIEdgeInsets(
//                top: 0,
//                left: Layout.postSideMargins,
//                bottom: 0,
//                right: Layout.postSideMargins
//            ),
//            respectSafeArea: false
//        )
//        self.textViewTopConstraint = top
//
//        self.textViewZeroHeightConstraint = NSLayoutConstraint(item: self.textView,
//                                                               attribute: .height,
//                                                               relatedBy: .equal,
//                                                               toItem: nil,
//                                                               attribute: .notAnAttribute,
//                                                               multiplier: 1,
//                                                               constant: 5)
//        self.textViewZeroHeightConstraint.isActive = false

//        self.addSubview(self.galleryView)
//        self.galleryView.pinTop(toBottomOf: self.textView, constant: 5)
//        self.galleryView.pinLeftToSuperview()
//        self.galleryView.constrainWidth(to: self)
//        galleryViewBottomConstraint = galleryView.bottomAnchor.constraint(equalTo: bottomAnchor)
//        galleryViewBottomConstraint?.isActive = true

//        self.galleryViewFullHeightConstraint = self.galleryView.heightAnchor.constraint(equalTo: self.galleryView.widthAnchor)
//        self.galleryViewZeroHeightConstraint = self.galleryView.heightAnchor.constraint(equalToConstant: 0)
//        self.galleryViewZeroHeightConstraint.isActive = true
    }

    convenience init(keyValue: KeyValue) {
        assert(keyValue.value.content.isPost)
        self.init()
        self.update(with: keyValue)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: KeyValueUpdateable

    override func update(with keyValue: KeyValue) {
        self.keyValue = keyValue
        self.headerView.update(with: keyValue)

        if let vote = keyValue.value.content.vote {
            var expression: String 
            if let explicitExpression = vote.vote.expression,
                explicitExpression.isSingleEmoji {
                expression = explicitExpression
            } else if vote.vote.value > 0 {
                expression = "\(Text.likesThis.text)"
            } else {
                expression = "\(Text.dislikesThis.text)"
            }

            let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.italicSystemFont(ofSize: 16),
                                                             .foregroundColor: UIColor.secondaryText]
            self.fullPostText = NSAttributedString(string: expression,
                                                   attributes: attributes)
            self.textView.text = expression
            self.configureTruncatedState()
            
            contentStackView.removeArrangedSubview(galleryView)
            galleryView.isHidden = true
//            self.galleryViewFullHeightConstraint.isActive = false
//            self.galleryViewZeroHeightConstraint.isActive = true
//            self.galleryViewBottomConstraint?.constant = 0
        } else if let post = keyValue.value.content.post {
//            let text = self.shouldTruncate ? Caches.truncatedText.from(keyValue) : Caches.text.from(keyValue)
            let text = Caches.text.from(keyValue)
            
            self.fullPostText = text
            self.configureTruncatedState()

//            self.galleryViewFullHeightConstraint.isActive = post.hasBlobs
//            self.galleryViewZeroHeightConstraint.isActive = !post.hasBlobs
            if post.hasBlobs {
                contentStackView.addArrangedSubview(galleryView)
                galleryView.isHidden = false
                self.galleryView.update(with: post)
            } else {
                contentStackView.removeArrangedSubview(galleryView)
                galleryView.isHidden = true
            }
//            self.galleryViewBottomConstraint?.constant = (post.hasBlobs && self.allowSpaceUnderGallery) ? -Layout.verticalSpacing : 0
        } else {
            return
        }

        // always do this in case of constraint changes
        textView.invalidateIntrinsicContentSize()
        contentStackView.invalidateIntrinsicContentSize()
        self.setNeedsLayout()
        self.layoutIfNeeded()
    }
}
