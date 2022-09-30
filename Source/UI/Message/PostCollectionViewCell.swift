//
//  PostCollectionViewCell.swift
//  Planetary
//
//  Created by Martin Dutra on 6/15/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import UIKit

class PostCollectionViewCell: UICollectionViewCell {
    
    private lazy var imageView: GalleryView = {
        let view = GalleryView()
        return view
    }()
    
    private lazy var imageOpacityView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.clipsToBounds = true
        view.layer.addSublayer(self.imageOpacityGradientLayer)
        return view
    }()
    
    private lazy var imageOpacityGradientLayer: CAGradientLayer = {
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 40)
        gradientLayer.colors = [UIColor.clear.cgColor,
                                UIColor.black.withAlphaComponent(0.7).cgColor]
        return gradientLayer
    }()
    
    private var imageViewSquareConstraint: NSLayoutConstraint?
    private var imageViewHeightConstraint: NSLayoutConstraint?
    private var imageViewBottomConstraint: NSLayoutConstraint?
    
    /// Activate or deactivate this constraint to make text view have no height,
    /// for instance, if the text is empty
    var textViewZeroHeightConstraint = NSLayoutConstraint()
    
    private lazy var textView: UITextView = {
        let view = UITextView.forAutoLayout()
        view.isEditable = false
        view.isScrollEnabled = false
        view.textContainerInset = UIEdgeInsets(top: 10, left: 10, bottom: 0, right: 10)
        view.textContainer.lineFragmentPadding = 0
        view.textContainer.lineBreakMode = .byTruncatingTail
        // view.textContainer.maximumNumberOfLines = 8
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        view.isUserInteractionEnabled = false
        view.backgroundColor = .cardBackground
        return view
    }()

    private lazy var headerView: SmallPostHeaderView = {
        let view = SmallPostHeaderView.forAutoLayout()
        view.backgroundColor = .cardBackground
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.contentView.clipsToBounds = true
        self.contentView.backgroundColor = .cardBackground
        self.contentView.layer.borderColor = UIColor.cardBorder.cgColor
        self.contentView.layer.borderWidth = 0.5
        self.contentView.layer.cornerRadius = 5
        
        Layout.fillTop(of: self.contentView, with: self.imageView, insets: .zero, respectSafeArea: false)
        self.imageViewSquareConstraint = self.imageView.constrainSquare()
        self.imageViewHeightConstraint = self.imageView.constrainHeight(to: 0)
        self.imageViewSquareConstraint?.isActive = false
        self.imageViewHeightConstraint?.isActive = true

        Layout.fillBottom(of: self.contentView, with: self.headerView, insets: .zero, respectSafeArea: false)
        self.headerView.constrainHeight(to: 40)
        
        self.contentView.insertSubview(self.imageOpacityView, belowSubview: self.headerView)
        imageOpacityView.constrain(attribute: .top, toAttribute: .top, ofView: self.headerView)
        imageOpacityView.constrain(attribute: .bottom, toAttribute: .bottom, ofView: self.headerView)
        imageOpacityView.constrain(attribute: .leading, toAttribute: .leading, ofView: self.headerView)
        imageOpacityView.constrain(attribute: .trailing, toAttribute: .trailing, ofView: self.headerView)

        self.contentView.addSubview(self.textView)
        // Layout.fillBottom(of: self.contentView, with: self.textView, insets: .zero, respectSafeArea: false)
        self.textView.constrainLeadingToSuperview()
        self.textView.constrainTrailingToSuperview()
        self.imageViewBottomConstraint = self.textView.pinTop(toBottomOf: self.imageView)
        self.textView.pinBottom(toTopOf: self.headerView)
        
        self.textViewZeroHeightConstraint = NSLayoutConstraint(item: self.textView,
                                                               attribute: .height,
                                                               relatedBy: .equal,
                                                               toItem: nil,
                                                               attribute: .notAnAttribute,
                                                               multiplier: 1,
                                                               constant: 0)
        self.textViewZeroHeightConstraint.isActive = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        self.imageViewSquareConstraint?.isActive = false
        self.imageViewHeightConstraint?.isActive = true
        self.imageViewBottomConstraint?.isActive = true
        self.textViewZeroHeightConstraint.isActive = false
        self.textView.text = nil
        // self.textView.textContainer.maximumNumberOfLines = 8
        
        self.headerView.backgroundColor = .cardBackground
        self.headerView.isOpaque = true
        self.headerView.startSkeletonAnimation()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        self.contentView.layer.borderColor = UIColor.cardBorder.cgColor
        self.contentView.setNeedsDisplay()
    }
    
    func update(message: Message) {
        guard let post = message.content.post else {
            return
        }
        if post.hasBlobs {
            self.imageView.update(with: post)
            self.imageViewSquareConstraint?.isActive = true
            self.imageViewHeightConstraint?.isActive = false
            // self.textView.textContainer.maximumNumberOfLines = 3
        }

        self.headerView.stopSkeletonAnimation()
        self.headerView.update(with: message)

        let textWithoutGallery = post.text.withoutGallery()
        if textWithoutGallery.withoutSpacesOrNewlines.isEmpty {
            self.textView.text = ""
            self.headerView.backgroundColor = .clear
            self.headerView.isOpaque = false
            self.imageViewBottomConstraint?.isActive = false
            self.textViewZeroHeightConstraint.isActive = true
        } else {
            self.textView.attributedText = textWithoutGallery.decodeMarkdown(small: true)

            if textWithoutGallery.isSingleEmoji {
                let size: CGFloat = self.contentView.bounds.width / 2
                self.textView.font = UIFont.smallPost.body.withSize(size)
                self.textView.textAlignment = .center
            }
        }
    }
}
