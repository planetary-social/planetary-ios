//
//  FloatingRefreshButton.swift
//  Planetary
//
//  Created by Martin Dutra on 5/26/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import UIKit

class FloatingRefreshButton: UIButton {
    
    init() {
        super.init(frame: .zero)
        self.useAutoLayout()
        let titleAttributes = [NSAttributedString.Key.font: UIFont.verse.floatingRefresh,
                               NSAttributedString.Key.foregroundColor: UIColor.white]
        let attributedTitle = NSAttributedString(string: Text.refresh.text.uppercased(), attributes: titleAttributes)
        self.setAttributedTitle(attributedTitle, for: .normal)
        self.backgroundColor = UIColor.tint.default
        self.contentEdgeInsets = .floatingRefreshButton
        self.isHidden = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func layout(in view: UIView, below tableView: UITableView) {
        Layout.centerHorizontally(self, in: view)
        self.constrainHeight(to: 32)
        self.roundedCorners(radius: 16)
        self.constrainTop(toTopOf: tableView, constant: 8)
    }
    
    func layout(in view: UIView, below collectionView: UICollectionView) {
        Layout.centerHorizontally(self, in: view)
        self.constrainHeight(to: 32)
        self.roundedCorners(radius: 16)
        self.constrainTop(toTopOf: collectionView, constant: 8)
    }
    
    func show(animated: Bool = true) {
        /*
        guard self.isHidden else {
            return
        }
        if animated {
            self.transform = CGAffineTransform(scaleX: 0, y: 0)
            self.isHidden = false
            UIView.animate(withDuration: 0.8,
                           delay: 0,
                           usingSpringWithDamping: CGFloat(0.40),
                           initialSpringVelocity: CGFloat(6.0),
                           options: UIView.AnimationOptions.allowUserInteraction,
                           animations: { self.transform = .identity },
                           completion: { _ in })
        } else {
            self.transform = .identity
            self.isHidden = false
        }*/
    }
    
    func hide(animated: Bool = true) {
        if animated {
            self.transform = .identity
            UIView.animate(withDuration: 0.8,
                           delay: 0,
                           usingSpringWithDamping: CGFloat(0.40),
                           initialSpringVelocity: CGFloat(6.0),
                           options: UIView.AnimationOptions.allowUserInteraction,
                           animations: { self.transform = CGAffineTransform(scaleX: 0, y: 0) },
                           completion: { _ in self.isHidden = true })
        } else {
            self.transform = CGAffineTransform(scaleX: 0, y: 0)
            self.isHidden = true
        }
    }
}
