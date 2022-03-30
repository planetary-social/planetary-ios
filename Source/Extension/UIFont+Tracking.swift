//
//  UIFont+Tracking.swift
//  Planetary
//
//  Created by Martin Dutra on 4/7/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

extension UIFont {
    
    // this translates the `tracking` from an Adobe-compatible value
    // based on the spacing and the font size
    func kerning(_ tracking: CGFloat) -> CGFloat {
        self.pointSize * tracking / 1_000
    }
}
