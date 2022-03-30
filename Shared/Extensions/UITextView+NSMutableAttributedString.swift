//
//  UITextView+NSMutableAttributedString.swift
//  FBTT
//
//  Created by Christoph on 6/24/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

extension UITextView {

    var mutableAttributedText: NSMutableAttributedString {
        NSMutableAttributedString(attributedString: self.attributedText)
    }

    func replaceText(in range: NSRange, with text: NSAttributedString) {
        let mutableText = self.mutableAttributedText
        mutableText.replaceCharacters(in: range, with: text)
        self.attributedText = mutableText
        let selectedRange = NSRange(location: range.location + text.length, length: 0)
        self.selectedRange = selectedRange
        self.delegate?.textViewDidChangeSelection?(self)
    }
}

extension NSMutableAttributedString {

    func removeAllAttributes(in range: NSRange? = nil) {
        let range = range ?? NSRange(location: 0, length: self.length)
        self.removeAttribute(NSAttributedString.Key.link, range: range)
    }
}
