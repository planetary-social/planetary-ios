//
//  UIImage+Round.swift
//  FBTT
//
//  Created by Christoph on 4/24/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

extension UIImage {

    func round(resizable: Bool = true) -> UIImage {
        assert(self.size.width == self.size.height, "Width and height must the same to make a round image")
        return self.rounded(by: self.size.width / 2, resizable: resizable)
    }

    func rounded(by radius: CGFloat, resizable: Bool = true) -> UIImage {
        let rect = CGRect(origin: CGPoint.zero, size: self.size)
        UIGraphicsBeginImageContextWithOptions(self.size, false, 1)
        UIBezierPath(roundedRect: rect,
                     cornerRadius: radius).addClip()
        self.draw(in: rect)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        if !resizable {
            return image ?? self
        } else {
            let insets = UIEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
            return image?.resizableImage(withCapInsets: insets) ?? self
        }
    }
}
