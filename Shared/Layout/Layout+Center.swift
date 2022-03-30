//
//  Layout+Center.swift
//  FBTT
//
//  Created by Christoph on 8/15/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

/// Center (add and pin a single edge)
extension Layout {

    static func center(_ subview: UIView,
                       in view: UIView,
                       size: CGSize? = nil) {
        subview.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(subview)

        let centerX = subview.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        let centerY = subview.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        NSLayoutConstraint.activate([centerX, centerY])

        guard let size = size else { return }
        let width = subview.widthAnchor.constraint(equalToConstant: size.width)
        let height = subview.heightAnchor.constraint(equalToConstant: size.height)
        NSLayoutConstraint.activate([width, height])
    }

    static func center(_ view: UIView,
                       atTopOf superview: UIView,
                       inset: CGFloat = 0,
                       respectSafeArea: Bool = true,
                       size: CGSize? = nil) {
        view.translatesAutoresizingMaskIntoConstraints = false
        superview.addSubview(view)

        let topAnchor = respectSafeArea ? superview.safeAreaLayoutGuide.topAnchor : superview.topAnchor

        let top = view.topAnchor.constraint(equalTo: topAnchor, constant: inset)
        let centerX = view.centerXAnchor.constraint(equalTo: superview.centerXAnchor)
        NSLayoutConstraint.activate([top, centerX])

        guard let size = size else { return }
        let width = view.widthAnchor.constraint(equalToConstant: size.width)
        let height = view.heightAnchor.constraint(equalToConstant: size.height)
        NSLayoutConstraint.activate([width, height])
    }
    
    static func centerHorizontally(_ subview: UIView,
                       in view: UIView,
                       size: CGSize? = nil) {
        subview.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(subview)

        let centerX = subview.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        NSLayoutConstraint.activate([centerX])

        guard let size = size else { return }
        let width = subview.widthAnchor.constraint(equalToConstant: size.width)
        let height = subview.heightAnchor.constraint(equalToConstant: size.height)
        NSLayoutConstraint.activate([width, height])
    }
}
