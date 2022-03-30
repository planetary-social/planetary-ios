//
//  Layout+Separator.swift
//  FBTT
//
//  Created by Christoph on 5/2/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

extension Layout {

    static let singlePixelHeight = CGFloat(1.0 / UIScreen.main.scale)

    @discardableResult
    static func addSeparator(toTopOf view: UIView,
                             height: CGFloat = Layout.singlePixelHeight,
                             left: CGFloat = 0,
                             right: CGFloat = 0,
                             color: UIColor = UIColor.separator.top) -> UIView {
        let separator = Layout.separatorView(height: height, left: left, right: right, color: color)
        Layout.fillTop(of: view, with: separator, insets: .zero)
        return separator
    }

    @discardableResult
    static func addSeparator(toBottomOf view: UIView,
                             height: CGFloat = Layout.singlePixelHeight,
                             left: CGFloat = 0,
                             right: CGFloat = 0,
                             color: UIColor = UIColor.separator.bottom) -> UIView {
        let separator = Layout.separatorView(height: height, left: left, right: right, color: color)
        separator.constrainHeight(to: height)
        Layout.fillBottom(of: view, with: separator, insets: .zero)
        return separator
    }

    @discardableResult
    static func addSeparator(southOf peerView: UIView,
                             height: CGFloat = Layout.singlePixelHeight,
                             left: CGFloat = 0,
                             right: CGFloat = 0,
                             color: UIColor = UIColor.separator.bottom) -> UIView {
        assert(peerView.superview != nil)
        let separator = Layout.separatorView(height: height, left: left, right: right, color: color)
        Layout.fillSouth(of: peerView, with: separator)
        return separator
    }

    static func separatorView(height: CGFloat = Layout.singlePixelHeight,
                              left: CGFloat = 0,
                              right: CGFloat = 0,
                              color: UIColor = UIColor.separator.middle,
                              backgroundColor: UIColor = .white) -> UIView {
        let backgroundView = UIView.forAutoLayout()
        backgroundView.backgroundColor = backgroundColor
        backgroundView.constrainHeight(to: height)
        let colorView = UIView.forAutoLayout()
        colorView.backgroundColor = color
        let insets = UIEdgeInsets(top: 0, left: left, bottom: 0, right: right)
        Layout.fill(view: backgroundView, with: colorView, insets: insets)
        return backgroundView
    }

    // a convenience for returning a tall separator view with a table background color
    // and a single-line separator on top and bottom
    // `top` and `bottom` arguments allow omitting one side or the other,
    // which is useful for preventing duplicate separators, when a neighboring element already has one
    static func sectionSeparatorView(top: Bool = true, bottom: Bool = true, color: UIColor = .appBackground) -> UIView {
        let separator = Layout.separatorView(height: 10, color: color)

        if top {
            Layout.addSeparator(toTopOf: separator)
        }

        if bottom {
            Layout.addSeparator(toBottomOf: separator)
        }

        return separator
    }
}
