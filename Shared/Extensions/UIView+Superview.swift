//
//  UIView+Superview.swift
//  Planetary
//
//  Created by Christoph on 11/4/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

extension UIView {

    func superview<T>(of type: T.Type) -> T? {
        superview as? T ?? superview?.superview(of: type)
    }

    func subview<T>(of type: T.Type) -> T? {
        subviews.compactMap { $0 as? T ?? $0.subview(of: type) }.first
    }
}
