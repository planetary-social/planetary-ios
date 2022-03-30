//
//  Layout+Fill.swift
//  FBTT
//
//  Created by Christoph on 8/15/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

/// Fill (add a subview to a view and pin multiple edges)
extension Layout {

    @discardableResult
    static func fill(view: UIView,
                     with subview: UIView,
                     insets: UIEdgeInsets = .zero,
                     respectSafeArea: Bool = true) -> TopLeftBottomRightConstraints {
        subview.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(subview)

        let topAnchor = respectSafeArea ? view.safeAreaLayoutGuide.topAnchor : view.topAnchor
        let bottomAnchor = respectSafeArea ? view.safeAreaLayoutGuide.bottomAnchor : view.bottomAnchor

        let top = subview.topAnchor.constraint(equalTo: topAnchor, constant: insets.top)
        let left = subview.leftAnchor.constraint(equalTo: view.leftAnchor, constant: insets.left)
        let bottom = subview.bottomAnchor.constraint(equalTo: bottomAnchor, constant: insets.bottom)
        bottom.priority = .defaultHigh
        let right = subview.rightAnchor.constraint(equalTo: view.rightAnchor, constant: insets.right)

        NSLayoutConstraint.activate([top, left, bottom, right])
        return (top, left, bottom, right)
    }

    @discardableResult
    static func fillTop(of view: UIView,
                        with subview: UIView,
                        insets: UIEdgeInsets = .zero,
                        respectSafeArea: Bool = true) -> TopLeftRightConstraints {
        subview.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(subview)

        let topAnchor = respectSafeArea ? view.safeAreaLayoutGuide.topAnchor : view.topAnchor

        let top = subview.topAnchor.constraint(equalTo: topAnchor, constant: insets.top)
        let left = subview.leftAnchor.constraint(equalTo: view.leftAnchor, constant: insets.left)
        let right = subview.rightAnchor.constraint(equalTo: view.rightAnchor, constant: insets.right)

        NSLayoutConstraint.activate([top, left, right])
        return (top, left, right)
    }

    @discardableResult
    static func fillLeft(of view: UIView,
                         with subview: UIView,
                         insets: UIEdgeInsets = .zero,
                         respectSafeArea: Bool = true) -> TopLeftBottomConstraints {
        subview.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(subview)

        let topAnchor = respectSafeArea ? view.safeAreaLayoutGuide.topAnchor : view.topAnchor
        let bottomAnchor = respectSafeArea ? view.safeAreaLayoutGuide.bottomAnchor : view.bottomAnchor

        let top = subview.topAnchor.constraint(equalTo: topAnchor, constant: insets.top)
        let left = subview.leftAnchor.constraint(equalTo: view.leftAnchor, constant: insets.left)
        let bottom = subview.bottomAnchor.constraint(equalTo: bottomAnchor, constant: insets.bottom)

        NSLayoutConstraint.activate([top, left, bottom])
        return (top, left, bottom)
    }

    @discardableResult
    static func fillBottom(of view: UIView,
                           with subview: UIView,
                           insets: UIEdgeInsets = .zero,
                           respectSafeArea: Bool = true) -> LeftBottomRightConstraints {
        subview.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(subview)

        let bottomAnchor = respectSafeArea ? view.safeAreaLayoutGuide.bottomAnchor : view.bottomAnchor

        let left = subview.leftAnchor.constraint(equalTo: view.leftAnchor, constant: insets.left)
        let bottom = subview.bottomAnchor.constraint(equalTo: bottomAnchor, constant: insets.bottom)
        bottom.priority = .defaultHigh
        let right = subview.rightAnchor.constraint(equalTo: view.rightAnchor, constant: insets.right)
        right.priority = .defaultHigh

        NSLayoutConstraint.activate([left, bottom, right])
        return (left, bottom, right)
    }

    @discardableResult
    static func fillRight(of view: UIView,
                          with subview: UIView,
                          insets: UIEdgeInsets = .zero,
                          respectSafeArea: Bool = true) -> TopBottomRightConstraints {
        subview.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(subview)

        let topAnchor = respectSafeArea ? view.safeAreaLayoutGuide.topAnchor : view.topAnchor
        let bottomAnchor = respectSafeArea ? view.safeAreaLayoutGuide.bottomAnchor : view.bottomAnchor

        let top = subview.topAnchor.constraint(equalTo: topAnchor, constant: insets.top)
        let bottom = subview.bottomAnchor.constraint(equalTo: bottomAnchor, constant: insets.bottom)
        let right = subview.rightAnchor.constraint(equalTo: view.rightAnchor, constant: insets.right)

        NSLayoutConstraint.activate([top, bottom, right])
        return (top, bottom, right)
    }

    @discardableResult
    static func fillTopLeft(of view: UIView,
                            with subview: UIView,
                            insets: UIEdgeInsets = .zero,
                            respectSafeArea: Bool = true) -> TopLeftConstraints {
        subview.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(subview)

        let topAnchor = respectSafeArea ? view.safeAreaLayoutGuide.topAnchor : view.topAnchor

        let top = subview.topAnchor.constraint(equalTo: topAnchor, constant: insets.top)
        let left = subview.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: insets.left)

        NSLayoutConstraint.activate([top, left])
        return (top, left)
    }

    @discardableResult
    static func fillTopRight(of view: UIView,
                             with subview: UIView,
                             insets: UIEdgeInsets = .zero,
                             respectSafeArea: Bool = true) -> TopRightConstraints {
        subview.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(subview)

        let topAnchor = respectSafeArea ? view.safeAreaLayoutGuide.topAnchor : view.topAnchor

        let top = subview.topAnchor.constraint(equalTo: topAnchor, constant: insets.top)
        let right = subview.rightAnchor.constraint(equalTo: view.rightAnchor, constant: insets.right)

        NSLayoutConstraint.activate([top, right])
        return (top, right)
    }

    @discardableResult
    static func fillBottomLeft(of view: UIView,
                               with subview: UIView,
                               insets: UIEdgeInsets = .zero,
                               respectSafeArea: Bool = true) -> LeftBottomConstraints {
        subview.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(subview)

        let bottomAnchor = respectSafeArea ? view.safeAreaLayoutGuide.bottomAnchor : view.bottomAnchor

        let left = subview.leftAnchor.constraint(equalTo: view.leftAnchor, constant: insets.left)
        let bottom = subview.bottomAnchor.constraint(equalTo: bottomAnchor, constant: insets.bottom)

        NSLayoutConstraint.activate([left, bottom])
        return (left, bottom)
    }

    @discardableResult
    static func fillBottomRight(of view: UIView,
                                with subview: UIView,
                                insets: UIEdgeInsets = .zero,
                                respectSafeArea: Bool = true) -> BottomRightConstraints {
        subview.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(subview)

        let bottomAnchor = respectSafeArea ? view.safeAreaLayoutGuide.bottomAnchor : view.bottomAnchor

        let bottom = subview.bottomAnchor.constraint(equalTo: bottomAnchor, constant: insets.bottom)
        let right = subview.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 0)

        NSLayoutConstraint.activate([bottom, right])
        return (bottom, right)
    }
}
