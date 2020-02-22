//
//  CGSize+Square.swift
//  FBTT
//
//  Created by Zef Houssney on 8/28/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import UIKit

extension CGSize {
    init(square dimension: CGFloat) {
        self.init(width: dimension, height: dimension)
    }
}
