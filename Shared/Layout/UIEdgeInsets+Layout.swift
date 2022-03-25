//
//  UIEdgeInsets+Layout.swift
//  FBTT
//
//  Created by Christoph on 3/21/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

extension UIEdgeInsets {
    static let `default` =          UIEdgeInsets(top: Layout.verticalSpacing, left: Layout.horizontalSpacing, bottom: -Layout.verticalSpacing, right: -Layout.horizontalSpacing)
    static let defaultText = UIEdgeInsets(top: Layout.verticalSpacing, left: Layout.horizontalSpacing, bottom: Layout.verticalSpacing, right: Layout.horizontalSpacing)
    static let leftBottomRight = UIEdgeInsets(top: 0, left: Layout.horizontalSpacing, bottom: -Layout.verticalSpacing, right: -Layout.horizontalSpacing)
    static let leftRight = UIEdgeInsets(top: 0, left: Layout.horizontalSpacing, bottom: 0, right: -Layout.horizontalSpacing)
    static let topOnly = UIEdgeInsets(top: Layout.verticalSpacing, left: 0, bottom: 0, right: 0)
    static let topLeft = UIEdgeInsets(top: Layout.verticalSpacing, left: Layout.horizontalSpacing, bottom: 0, right: 0)
    static let topRight = UIEdgeInsets(top: Layout.verticalSpacing, left: 0, bottom: 0, right: -Layout.horizontalSpacing)
    static let topLeftRight = UIEdgeInsets(top: Layout.verticalSpacing, left: Layout.horizontalSpacing, bottom: 0, right: -Layout.horizontalSpacing)
    static let topLeftBottom = UIEdgeInsets(top: Layout.verticalSpacing, left: Layout.horizontalSpacing, bottom: -Layout.verticalSpacing, right: 0)
    static let topBottomRight = UIEdgeInsets(top: Layout.verticalSpacing, left: 0, bottom: -Layout.verticalSpacing, right: -Layout.horizontalSpacing)
    static let debugTableViewCell = UIEdgeInsets(top: Layout.verticalSpacing, left: Layout.horizontalSpacing, bottom: -Layout.verticalSpacing, right: -Layout.horizontalSpacing)

    static let pillButton = UIEdgeInsets(top: 0, left: 15, bottom: 0, right: 15)
    static let floatingRefreshButton = UIEdgeInsets(top: 0, left: 30, bottom: 0, right: 30)
}

extension UIEdgeInsets {

    static func top(_ constant: CGFloat) -> UIEdgeInsets {
        UIEdgeInsets(top: constant, left: 0, bottom: 0, right: 0)
    }

    static func left(_ constant: CGFloat) -> UIEdgeInsets {
        UIEdgeInsets(top: 0, left: constant, bottom: 0, right: 0)
    }

    static func bottom(_ constant: CGFloat) -> UIEdgeInsets {
        UIEdgeInsets(top: 0, left: 0, bottom: constant, right: 0)
    }

    static func right(_ constant: CGFloat) -> UIEdgeInsets {
        UIEdgeInsets(top: 0, left: 0, bottom: 0, right: constant)
    }

    static func square(_ constant: CGFloat) -> UIEdgeInsets {
        UIEdgeInsets(top: constant, left: constant, bottom: constant, right: constant)
    }
}
