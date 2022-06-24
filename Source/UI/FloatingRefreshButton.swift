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
        self.backgroundColor = UIColor.floatingRefreshButton
        self.contentEdgeInsets = .pillButton
        self.isHidden = true
    }
    
    required init?(coder: NSCoder) {
        nil
    }

    func makeRoundedAndShadowed() {
        layer.masksToBounds = false
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: layer.cornerRadius).cgPath
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowOpacity = 0.25
        layer.shadowRadius = 4
        layer.cornerRadius = 16
    }

    func updateShadowLayer() {
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: layer.cornerRadius).cgPath
    }

    func setTitle(with count: Int) {
        let titleAttributes = [
            NSAttributedString.Key.font: UIFont.verse.floatingRefresh,
            NSAttributedString.Key.foregroundColor: UIColor.white
        ]
        let boldTitleAttributes = [
            NSAttributedString.Key.font: UIFont.verse.floatingRefreshBold,
            NSAttributedString.Key.foregroundColor: UIColor.white
        ]
        let countString = "\(count)"
        let arguments = ["count": countString]
        let string = count == 1 ? Text.refreshSingular.text(arguments) : Text.refreshPlural.text(arguments)
        let attributedTitle = NSMutableAttributedString(string: string, attributes: titleAttributes)
        let stringRange = string.startIndex ..< string.endIndex
        string.enumerateSubstrings(in: stringRange, options: .byWords) { (substring, substringRange, _, _) in
            if substring == countString {
                attributedTitle.setAttributes(boldTitleAttributes, range: NSRange(substringRange, in: string))
            }
        }
        self.setAttributedTitle(attributedTitle, for: .normal)
        updateShadowLayer()
    }
    
    func layout(in view: UIView, below tableView: UITableView) {
        Layout.centerHorizontally(self, in: view)
        self.constrainHeight(to: 32)
        self.makeRoundedAndShadowed()
        self.constrainTop(toTopOf: tableView, constant: 10)
    }
    
    func layout(in view: UIView, below collectionView: UICollectionView) {
        Layout.centerHorizontally(self, in: view)
        self.constrainHeight(to: 32)
        self.makeRoundedAndShadowed()
        self.constrainTop(toTopOf: collectionView, constant: 8)
    }
    
    func show(animated: Bool = true) {
        guard self.isHidden else {
            return
        }
        if animated {
            self.transform = CGAffineTransform(scaleX: 0, y: 0)
            self.isHidden = false
            UIView.animate(
                withDuration: 0.8,
                delay: 0,
                usingSpringWithDamping: CGFloat(0.40),
                initialSpringVelocity: CGFloat(6.0),
                options: UIView.AnimationOptions.allowUserInteraction,
                animations: { self.transform = .identity },
                completion: { _ in }
            )
        } else {
            self.transform = .identity
            self.isHidden = false
        }
    }
    
    func hide(animated: Bool = true) {
        if animated {
            self.transform = .identity
            UIView.animate(
                withDuration: 0.8,
                delay: 0,
                usingSpringWithDamping: CGFloat(0.40),
                initialSpringVelocity: CGFloat(6.0),
                options: UIView.AnimationOptions.allowUserInteraction,
                animations: { self.transform = CGAffineTransform(scaleX: 0, y: 0) },
                completion: { _ in self.isHidden = true }
            )
        } else {
            self.transform = CGAffineTransform(scaleX: 0, y: 0)
            self.isHidden = true
        }
    }
}
