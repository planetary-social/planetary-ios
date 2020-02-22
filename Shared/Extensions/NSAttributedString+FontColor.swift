//
//  NSAttributedString+FontColor.swift
//  FBTT
//
//  Created by Christoph on 8/7/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

extension NSAttributedString {

    convenience init(_ string: String, font: UIFont, color: UIColor = .black) {
        let attributes = [NSAttributedString.Key.font: font,
                          NSAttributedString.Key.foregroundColor: color]
        self.init(string: string, attributes: attributes)
    }
}
