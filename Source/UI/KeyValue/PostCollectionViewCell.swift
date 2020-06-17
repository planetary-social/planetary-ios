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
        view.textContainerInset = .square(10)
        view.textContainer.lineFragmentPadding = 0
        view.textContainer.lineBreakMode = .byTruncatingTail
        view.textContainer.maximumNumberOfLines = 9
        view.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.contentView.clipsToBounds = true
        self.contentView.backgroundColor = .white
        self.contentView.layer.borderColor = UIColor(rgb: 0xc3c3c3).cgColor
        self.contentView.layer.borderWidth = 0.5
        self.contentView.layer.cornerRadius = 5
        
        Layout.fillTop(of: self.contentView, with: self.imageView, insets: .zero, respectSafeArea: false)
        self.imageViewSquareConstraint = self.imageView.constrainSquare()
        self.imageViewHeightConstraint = self.imageView.constrainHeight(to: 0)
        self.imageViewSquareConstraint?.isActive = false
        self.imageViewHeightConstraint?.isActive = true
        
        Layout.fillBottom(of: self.contentView, with: self.textView, insets: .zero, respectSafeArea: false)
        self.textView.pinTop(toBottomOf: self.imageView, constant: 0)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        self.imageViewSquareConstraint?.isActive = false
        self.imageViewHeightConstraint?.isActive = true
    }
    
    func update(keyValue: KeyValue) {
        guard let post = keyValue.value.content.post else {
            return
        }
        if post.hasBlobs {
            self.imageView.update(with: post)
            self.imageViewSquareConstraint?.isActive = true
            self.imageViewHeightConstraint?.isActive = false
        }
        textView.text = post.text.withoutGallery()
    }
}
