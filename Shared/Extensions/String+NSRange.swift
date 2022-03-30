//
//  String+NSRange.swift
//  FBTT
//
//  Created by Christoph on 9/20/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

extension String {

    func rangeFromNSRange(nsRange: NSRange) -> Range<String.Index>? {
        Range(nsRange, in: self)
    }
}
