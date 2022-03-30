//
//  UIVIew+HeaderView.swift
//  FBTT
//
//  Created by Christoph on 4/25/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

extension UIView {

    /// Returns a UIView with the specified view as a child and a
    /// colored separator view at the bottom.
    static func headerView(with view: UIView,
                           separator color: UIColor = UIColor.separator.top) -> UIView {
        let header = UIView.forAutoLayout()
        Layout.fillTop(of: header, with: view, respectSafeArea: false)
        let separator = UIView.forAutoLayout()
        separator.backgroundColor = color
        separator.constrainHeight(to: 9)
        Layout.fillSouth(of: view, with: separator)
        separator.pinBottomToSuperviewBottom()
        return header
    }
}
