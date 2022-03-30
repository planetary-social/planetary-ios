//
//  ImageGalleryView.swift
//  FBTT
//
//  Created by Christoph on 9/10/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

protocol ImageGalleryViewDelegate: NSObject {

    func imageGalleryViewDidChange(_ view: ImageGalleryView)
    func imageGalleryView(_ view: ImageGalleryView, didSelect image: UIImage, at indexPath: IndexPath)
}

class ImageGalleryView: UIView {

    weak var delegate: ImageGalleryViewDelegate?

    fileprivate var _images: [UIImage] = []
    var images: [UIImage] {
        self._images
    }

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 6
        layout.sectionInset = UIEdgeInsets.square(6)
        layout.itemSize = CGSize.init(square: self.heightConstant - 12)
        layout.scrollDirection = .horizontal
        let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.backgroundColor = .cardBackground
        view.dataSource = self
        view.delegate = self
        view.register(ImageGalleryCell.self, forCellWithReuseIdentifier: ImageGalleryCell.identifier)
        return view
    }()

    private let heightConstant: CGFloat

    init(height: CGFloat = 75) {
        self.heightConstant = height
        super.init(frame: .zero)
        self.constrainHeight(to: 0)
        Layout.fill(view: self, with: self.collectionView)
        Layout.addSeparator(toTopOf: self)
        self.collectionView.reloadData()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Animations

    func open() {
        self.heightConstraint?.constant = self.heightConstant
    }

    func close() {
        self.heightConstraint?.constant = 0
    }

    // MARK: Image management

    func add(_ image: UIImage) {
        self._images += [image]
        self.collectionView.reloadData()
        let indexPath = self.images.indexPathForLast()
        self.collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: false)
        self.delegate?.imageGalleryViewDidChange(self)
    }

    func add(_ images: [UIImage]) {
        self._images += images
        self.collectionView.reloadData()
        let indexPath = self.images.indexPathForLast()
        self.collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: false)
        self.delegate?.imageGalleryViewDidChange(self)
    }

    func remove(at indexPath: IndexPath) {
        self._images.remove(at: indexPath.row)
        self.reload()
    }

    func removeAll() {
        self._images.removeAll()
        self.reload()
    }

    private func reload() {
        self.collectionView.reloadData()
        self.delegate?.imageGalleryViewDidChange(self)
    }
}

extension ImageGalleryView: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        self._images.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ImageGalleryCell.identifier,
                                                      for: indexPath) as! ImageGalleryCell
        cell.imageView.image = self._images[indexPath.row]
        return cell
    }
}

extension ImageGalleryView: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        self.delegate?.imageGalleryView(self, didSelect: self.images[indexPath.row], at: indexPath)
    }
}

private class ImageGalleryCell: UICollectionViewCell {

    static let identifier = ImageGalleryCell.className

    let imageView: UIImageView = {
        let view = UIImageView.forAutoLayout()
        view.backgroundColor = .debug
        view.clipsToBounds = true
        view.contentMode = .scaleAspectFill
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        Layout.fill(view: self.contentView,
                    with: self.imageView)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
