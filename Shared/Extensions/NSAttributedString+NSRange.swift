//
//  NSAttributedString+NSRange.swift
//  FBTT
//
//  Created by Christoph on 6/25/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

extension NSAttributedString {

    var range: NSRange {
        NSRange(location: 0, length: self.length)
    }
}
