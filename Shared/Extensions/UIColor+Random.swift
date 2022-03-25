//
//  UIColor+Random.swift
//  FBTT
//
//  Created by Christoph on 7/12/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

extension UIColor {

    static func random() -> UIColor {
        let r = CGFloat(arc4random() % 256) / 256
        let g = CGFloat(arc4random() % 256) / 256
        let b = CGFloat(arc4random() % 256) / 256
        return UIColor(red: r, green: g, blue: b, alpha: 1.0)
    }
}
