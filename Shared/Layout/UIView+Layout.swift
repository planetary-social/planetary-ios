//
//  UIView+Layout.swift
//  FBTT
//
//  Created by Christoph on 3/21/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

// TODO https://app.asana.com/0/914798787098068/1135834818731960/f
// This has some inconsistencies in the interface, but I think it needs
// to be used a bit more before the concrete patterns appear.  In particular
// the funcs that take an activate argument are no simpler than using the
// anchors directly, so examine if those are needed.
extension UIView {

    // MARK: Pin to peers or superviews

    @discardableResult
    func pinTop(toBottomOf view: UIView,
                constant: CGFloat = 0,
                activate: Bool = true) -> NSLayoutConstraint
    {
        let constraint = self.topAnchor.constraint(equalTo: view.bottomAnchor, constant: constant)
        constraint.isActive = activate
        return constraint
    }

    @discardableResult
    func pinTopToSuperview(constant: CGFloat = 0, respectSafeArea: Bool = true) -> NSLayoutConstraint? {
        guard let superview = self.superview else { return nil }
        let topAnchor = respectSafeArea ? superview.safeAreaLayoutGuide.topAnchor : superview.topAnchor
        let constraint = self.topAnchor.constraint(equalTo: topAnchor, constant: constant)
        constraint.isActive = true
        return constraint
    }

    @discardableResult
    func pinLeftToSuperview(constant: CGFloat = 0) -> NSLayoutConstraint? {
        guard let superview = self.superview else { return nil }
        let constraint = self.leftAnchor.constraint(equalTo: superview.leftAnchor, constant: constant)
        constraint.isActive = true
        return constraint
    }

    @discardableResult
    func pinRightToSuperview(constant: CGFloat = 0) -> NSLayoutConstraint? {
        guard let superview = self.superview else { return nil }
        let constraint = self.rightAnchor.constraint(equalTo: superview.rightAnchor, constant: constant)
        constraint.priority = .defaultLow
        constraint.isActive = true
        return constraint
    }

    @discardableResult
    func pinBottomToSuperviewBottom(constant: CGFloat = 0, respectSafeArea: Bool = true) -> NSLayoutConstraint? {
        guard let superview = self.superview else { return nil }
        let bottomAnchor = respectSafeArea ? superview.safeAreaLayoutGuide.bottomAnchor : superview.bottomAnchor
        let constraint = self.bottomAnchor.constraint(equalTo: bottomAnchor, constant: constant)
        constraint.priority = .defaultLow
        constraint.isActive = true
        return constraint
    }

    @discardableResult
    func pinBottom(toTopOf view: UIView,
                   constant: CGFloat = 0,
                   activate: Bool = true) -> NSLayoutConstraint
    {
        let constraint = self.bottomAnchor.constraint(equalTo: view.topAnchor, constant: constant)
        constraint.isActive = activate
        return constraint
    }

    // MARK: Constrain width and height

    @discardableResult
    func constrainHeight(to constant: CGFloat) -> NSLayoutConstraint {
        let constraint = self.heightAnchor.constraint(equalToConstant: constant)
        constraint.isActive = true
        return constraint
    }

    @discardableResult
    func constrainHeight(lessThanOrEqualTo constant: CGFloat) -> NSLayoutConstraint {
        let constraint = self.heightAnchor.constraint(lessThanOrEqualToConstant: constant)
        constraint.isActive = true
        return constraint
    }

    @discardableResult
    func constrainHeight(greaterThanOrEqualTo constant: CGFloat) -> NSLayoutConstraint {
        let constraint = self.heightAnchor.constraint(greaterThanOrEqualToConstant: constant)
        constraint.isActive = true
        return constraint
    }

    func constrainHeight(to peerView: UIView) {
        self.translatesAutoresizingMaskIntoConstraints = false
        let constraint = self.heightAnchor.constraint(equalTo: peerView.heightAnchor, constant: 0)
        constraint.priority = .defaultHigh
        constraint.isActive = true
    }

    func constrainWidth(to constant: CGFloat) {
        self.translatesAutoresizingMaskIntoConstraints = false
        let constraint = self.widthAnchor.constraint(equalToConstant: constant)
        constraint.isActive = true
    }

    func constrainWidth(to peerView: UIView, constant: CGFloat = 0) {
        self.translatesAutoresizingMaskIntoConstraints = false
        let constraint = self.widthAnchor.constraint(equalTo: peerView.widthAnchor, constant: constant)
        constraint.priority = .defaultHigh
        constraint.isActive = true
    }

    func constrainSize(to dimension: CGFloat) {
        self.constrainWidth(to: dimension)
        self.constrainHeight(to: dimension)
    }

    func constrainSize(to size: CGSize) {
        self.constrainWidth(to: size.width)
        self.constrainHeight(to: size.height)
    }
    
    @discardableResult
    func constrainSquare() -> NSLayoutConstraint {
        self.translatesAutoresizingMaskIntoConstraints = false
        let constraint = self.widthAnchor.constraint(equalTo: self.heightAnchor, multiplier: 1)
        constraint.priority = .defaultHigh
        constraint.isActive = true
        return constraint
    }


    func constrain(to view: UIView) {
        self.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        self.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        self.widthAnchor.constraint(equalTo: view.widthAnchor).isActive = true
        self.heightAnchor.constraint(equalTo: view.heightAnchor).isActive = true
    }

    // MARK: Constrain to edges (may be duplicates or unnecessary)

    func constrainLeadingToSuperview(constant: CGFloat = 0) {
        assert(self.superview != nil)
        self.leadingAnchor.constraint(equalTo: superview!.leadingAnchor,
                                      constant: constant).isActive = true
    }

    func constrainLeading(to view: UIView, constant: CGFloat = 0) {
        self.leadingAnchor.constraint(equalTo: view.leadingAnchor,
                                      constant: constant).isActive = true
    }

    func constrainLeading(toTrailingOf view: UIView, constant: CGFloat = 8) {
        self.leadingAnchor.constraint(equalTo: view.trailingAnchor,
                                      constant: constant).isActive = true
    }

    func constrainTrailingToSuperview(constant: CGFloat = 0) {
        assert(self.superview != nil)
        self.trailingAnchor.constraint(equalTo: superview!.trailingAnchor,
                                      constant: constant).isActive = true
    }

    func constrainTrailing(toTrailingOf view: UIView, constant: CGFloat = 0) {
        self.trailingAnchor.constraint(equalTo: view.trailingAnchor,
                                       constant: constant).isActive = true
    }

    func constrainTrailing(toLeadingOf view: UIView, constant: CGFloat = -8) {
        self.trailingAnchor.constraint(equalTo: view.leadingAnchor,
                                       constant: constant).isActive = true
    }

    func constrainTop(toTopOf view: UIView, constant: CGFloat = 0) {
        self.topAnchor.constraint(equalTo: view.topAnchor,
                                  constant: constant).isActive = true
    }
    
    func constrainBottom(toBottomOf view: UIView, constant: CGFloat = 0) {
        self.bottomAnchor.constraint(equalTo: view.bottomAnchor,
                                  constant: constant).isActive = true
    }
}
