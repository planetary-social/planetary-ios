//
//  UIPageControl+Verse.swift
//  FBTT
//
//  Created by Christoph on 9/5/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

extension UIPageControl {

    static func `default`() -> UIPageControl {
        let control = UIPageControl.forAutoLayout()
        control.currentPageIndicatorTintColor = UIColor.tint.default
        control.pageIndicatorTintColor = UIColor.black.withAlphaComponent(0.25)
        return control
    }
}
