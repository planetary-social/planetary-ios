//
//  NSAttributedString+Mutable.swift
//  Planetary
//
//  Created by Christoph on 12/17/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

extension NSAttributedString {

    func mutable() -> NSMutableAttributedString {
        NSMutableAttributedString(attributedString: self)
    }
}
