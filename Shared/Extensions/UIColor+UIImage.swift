//
//  UIColor+UIImage.swift
//  FBTT
//
//  Created by Christoph on 7/12/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

extension UIColor {

    func image(dimension: CGFloat) -> UIImage {
        self.image(size: CGSize(width: dimension, height: dimension))
    }

    func image(size: CGSize = CGSize(width: 32, height: 32)) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = UIScreen.main.scale
        return UIGraphicsImageRenderer(size: size, format: format).image {
            rendererContext in
            self.setFill()
            rendererContext.fill(CGRect(x: 0, y: 0, width: size.width, height: size.height))
        }
    }
}
