//
//  UIColor+Hex.swift
//  FBTT
//
//  Created by Christoph on 3/24/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

// Simplified way to support HEX colors without including a pod or framework.
// https://stackoverflow.com/questions/24263007/how-to-use-hex-color-values
extension UIColor {

    convenience init(red: Int, green: Int, blue: Int) {
        assert(red >= 0 && red <= 255, "Invalid red component")
        assert(green >= 0 && green <= 255, "Invalid green component")
        assert(blue >= 0 && blue <= 255, "Invalid blue component")
        self.init(red: CGFloat(red) / 255.0,
                  green: CGFloat(green) / 255.0,
                  blue: CGFloat(blue) / 255.0,
                  alpha: 1.0)
    }

    convenience init(rgb: Int) {
        self.init(red: (rgb >> 16) & 0xFF,
                  green: (rgb >> 8) & 0xFF,
                  blue: rgb & 0xFF
        )
    }

    convenience init(red: Int, green: Int, blue: Int, a: CGFloat = 1.0) {
        self.init(red: CGFloat(red) / 255.0,
                  green: CGFloat(green) / 255.0,
                  blue: CGFloat(blue) / 255.0,
                  alpha: a
        )
    }

    convenience init(rgb: Int, a: CGFloat = 1.0) {
        self.init(red: (rgb >> 16) & 0xFF,
                  green: (rgb >> 8) & 0xFF,
                  blue: rgb & 0xFF,
                  a: a
        )
    }

    convenience init(rgb: Int, a: Int) {
        self.init(red: (rgb >> 16) & 0xFF,
                  green: (rgb >> 8) & 0xFF,
                  blue: rgb & 0xFF,
                  a: CGFloat(a) / 255.0
        )
    }

    /// Returns an integer representing the red, green, and blue
    /// bits for this color.  Because the alpha channel is not included,
    /// the 4 byte format is XXRRGGBB.  This requires that the color
    /// is in the monochrome or RGB color spaces.  If not, then the
    /// returned value will always be nil.
    var rgb: Int? {

        guard let space = self.cgColor.colorSpace else { return nil }
        guard let components = self.cgColor.components else { return nil }
        var r = Int(0), g = Int(0), b = Int(0)

        // monochrome to rgb
        if space.model == .monochrome {
            r = Int(components[0] * 255)
            g = Int(components[0] * 255)
            b = Int(components[0] * 255)
        }

        // rgb
        else if space.model == .rgb {
            r = Int(components[0] * 255)
            g = Int(components[1] * 255)
            b = Int(components[2] * 255)
        }

        // unsupported color space
        else {
            return nil
        }

        // bit shift components into place
        let rgb = r << 16 + g << 8 + b
        return rgb
    }
}
