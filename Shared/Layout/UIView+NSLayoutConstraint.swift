//
//  UIView+NSLayoutConstraint.swift
//  FBTT
//
//  Created by Christoph on 7/2/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

extension UIView {

    var widthConstraint: NSLayoutConstraint? {
        get {
            constraints.first { $0.firstAttribute == .width && $0.relation == .equal }
        }
    }

    var heightConstraint: NSLayoutConstraint? {
        get {
            constraints.first { $0.firstAttribute == .height && $0.relation == .equal }
        }
    }
}
