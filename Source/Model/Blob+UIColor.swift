//
//  Blob+UIColor.swift
//  Planetary
//
//  Created by Christoph on 11/23/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

extension Blob.Metadata {

    var averageColor: UIColor? {
        guard let rgb = self.averageColorRGB else { return nil }
        return UIColor(rgb: rgb)
    }
}
