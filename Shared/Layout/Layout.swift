//
//  Layout.swift
//  FBTT
//
//  Created by Christoph on 1/12/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

/// Note that some bottom and right constraints `priority = .defaultHigh` to allow
/// breaking if the parent view hierarchy widht or height is zero, typically when
/// a view is used in a UITableView.
///
/// Also note that this favors vertical designs, and ignores horizontal safe areas.
/// This could be problematic if the app allows landscapes modes, but for now does not.
/// One possibility is that respectSafeArea: Bool could be expressed as a tuple
/// representing the edges (top, left, bottom, right) as (Bool?, Bool?, Bool?, Bool?).
struct Layout {
    static var verticalSpacing: CGFloat = 15
    static var horizontalSpacing: CGFloat = 15

    static var postSideMargins: CGFloat {
        horizontalSpacing - 1
    }

    static var profileThumbSize: CGFloat = 35

    static var profileImageInside: CGFloat = 167
    static var profileImageOutside: CGFloat = 182

    static func spacing(_ axis: NSLayoutConstraint.Axis) -> CGFloat {
        axis == .horizontal ? horizontalSpacing : verticalSpacing
    }
}

/// Constraints are typically expressed in top,left and bottom,right order.
/// These are conveniences to be clear on which constraints will be returned,
/// and follows that order for consistency.
typealias TopLeftBottomRightConstraints = (NSLayoutConstraint, NSLayoutConstraint, NSLayoutConstraint, NSLayoutConstraint)
typealias TopLeftRightConstraints = (NSLayoutConstraint, NSLayoutConstraint, NSLayoutConstraint)
typealias TopLeftConstraints = (NSLayoutConstraint, NSLayoutConstraint)
typealias TopRightConstraints = (NSLayoutConstraint, NSLayoutConstraint)
typealias TopLeftBottomConstraints = (NSLayoutConstraint, NSLayoutConstraint, NSLayoutConstraint)
typealias TopBottomRightConstraints = (NSLayoutConstraint, NSLayoutConstraint, NSLayoutConstraint)
typealias LeftBottomRightConstraints = (NSLayoutConstraint, NSLayoutConstraint, NSLayoutConstraint)
typealias BottomRightConstraints = (NSLayoutConstraint, NSLayoutConstraint)
typealias LeftBottomConstraints = (NSLayoutConstraint, NSLayoutConstraint)
