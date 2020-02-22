//
//  UIView+Shake.swift
//  FBTT
//
//  Created by Christoph on 7/26/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

extension UIView {

    func shake() {
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
        animation.duration = 0.5
        animation.values = [-18.0, 18.0, -18.0, 18.0, -9.0, 9.0, -5.0, 5.0, 0.0 ]
        layer.add(animation, forKey: "shake")
    }
}
