//
//  NSMutableAttributedString+Attributes.swift
//  FBTT
//
//  Created by Christoph on 7/3/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

extension NSMutableAttributedString {

    /// Convenience func to apply attributes to the entire string.
    func addAttributes(_ attributes: [NSAttributedString.Key: Any]) {
        let range = NSRange(location: 0, length: self.length)
        self.addAttributes(attributes, range: range)
    }

    /// Convenience func to add a `NSAttributedString.Key.link` value to a substring.
    func addLinkAttribute(value: String, to substring: String) {
        let range = (self.string as NSString).range(of: substring)
        self.addAttributes([NSAttributedString.Key.link: value], range: range)
    }

    /// Convenience func to add a `NSAttributedString.Key.Font` and/or
    /// `NSAttributedString.Key.ForegroundColor` across the entire string.
    func addFontAttribute(_ font: UIFont, colorAttribute color: UIColor = .black) {
        self.addAttributes([NSAttributedString.Key.font: font, NSAttributedString.Key.foregroundColor: color])
    }

    func addColorAttribute(_ color: UIColor) {
        self.addAttributes([NSAttributedString.Key.foregroundColor: color])
    }
    
    func addParagraphAlignLeft() {
        let style = NSMutableParagraphStyle()
        style.alignment = .left
        self.addAttributes([NSAttributedString.Key.paragraphStyle: style])
    }
    
    func addAttributes(_ attributes: [NSAttributedString.Key: Any], to substring: String) {
        let range = (self.string as NSString).range(of: substring)
        self.addAttributes(attributes, range: range)
    }
}
