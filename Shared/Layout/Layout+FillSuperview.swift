//
//  Layout+FillSuperview.swift
//  FBTT
//
//  Created by Christoph on 8/15/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

/// Fill the superview next to a peer
extension Layout {

    /// Adds and constrains the specified view to the same superview as the
    /// specified peer.  In this case, the view is added SOUTH of the peer view.
    /// This is useful in a top-down programmatic layout.
    @discardableResult
    static func fillSouth(of peerView: UIView,
                          with subview: UIView,
                          insets: UIEdgeInsets = .zero) -> TopLeftRightConstraints {
        assert(peerView.superview != nil)
        let superview = peerView.superview!
        subview.translatesAutoresizingMaskIntoConstraints = false
        superview.addSubview(subview)

        let top = subview.topAnchor.constraint(equalTo: peerView.bottomAnchor, constant: insets.top)
        let left = subview.leadingAnchor.constraint(equalTo: superview.leadingAnchor, constant: insets.left)
        let right = subview.trailingAnchor.constraint(equalTo: superview.trailingAnchor, constant: insets.right)

        NSLayoutConstraint.activate([top, left, right])
        return (top, left, right)
    }

    /// Similar to `fillSouth(of:with:insets)` but useful when building
    /// bottom-up layouts.
    @discardableResult
    static func fillNorth(of peerView: UIView,
                          with subview: UIView,
                          insets: UIEdgeInsets = .zero) -> LeftBottomRightConstraints {
        assert(peerView.superview != nil)
        let superview = peerView.superview!
        subview.translatesAutoresizingMaskIntoConstraints = false
        superview.addSubview(subview)

        let left = subview.leadingAnchor.constraint(equalTo: superview.leadingAnchor, constant: insets.left)
        let bottom = subview.bottomAnchor.constraint(equalTo: peerView.topAnchor, constant: insets.bottom)
        let right = subview.trailingAnchor.constraint(equalTo: superview.trailingAnchor, constant: insets.right)

        NSLayoutConstraint.activate([left, bottom, right])
        return (left, bottom, right)
    }
}
