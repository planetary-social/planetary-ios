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
    
    private var imageViewSquareConstraint: NSLayoutConstraint?
    private var imageViewHeightConstraint: NSLayoutConstraint?
    
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
        view.backgroundColor = UIColor.post.background
        return view
    }()

    private lazy var headerView: SmallPostHeaderView = {
        let view = SmallPostHeaderView.forAutoLayout()
        view.backgroundColor = UIColor.post.background
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.contentView.clipsToBounds = true
        self.contentView.backgroundColor = UIColor.post.background
        self.contentView.layer.borderColor = UIColor.post.border.cgColor
        self.contentView.layer.borderWidth = 0.5
        self.contentView.layer.cornerRadius = 5
        
        Layout.fillTop(of: self.contentView, with: self.imageView, insets: .zero, respectSafeArea: false)
        self.imageViewSquareConstraint = self.imageView.constrainSquare()
        self.imageViewHeightConstraint = self.imageView.constrainHeight(to: 0)
        self.imageViewSquareConstraint?.isActive = false
        self.imageViewHeightConstraint?.isActive = true

        Layout.fillBottom(of: self.contentView, with: self.headerView, insets: .zero, respectSafeArea: false)
        self.headerView.constrainHeight(to: 40)

        self.contentView.addSubview(self.textView)
        // Layout.fillBottom(of: self.contentView, with: self.textView, insets: .zero, respectSafeArea: false)
        self.textView.constrainLeadingToSuperview()
        self.textView.constrainTrailingToSuperview()
        self.textView.pinTop(toBottomOf: self.imageView)
        self.textView.pinBottom(toTopOf: self.headerView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        self.imageViewSquareConstraint?.isActive = false
        self.imageViewHeightConstraint?.isActive = true
        self.textView.text = nil
        // self.textView.textContainer.maximumNumberOfLines = 8
        
        self.headerView.startSkeletonAnimation()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        self.contentView.layer.borderColor = UIColor.post.border.cgColor
        self.contentView.setNeedsDisplay()
    }

    func update(keyValue: KeyValue) {
        guard let post = keyValue.value.content.post else {
            return
        }
        if post.hasBlobs {
            self.imageView.update(with: post)
            self.imageViewSquareConstraint?.isActive = true
            self.imageViewHeightConstraint?.isActive = false
            // self.textView.textContainer.maximumNumberOfLines = 3
        }
        self.textView.attributedText = post.text.withoutGallery().decodeMarkdown(small: true)
        self.headerView.stopSkeletonAnimation()
        self.headerView.update(with: keyValue)
    }
}
