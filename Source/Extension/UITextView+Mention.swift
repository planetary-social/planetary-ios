//
//  UITextView+Mention.swift
//  FBTT
//
//  Created by Christoph on 7/3/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

extension UITextView {

    func replaceText(in range: NSRange,
                     with mention: Mention,
                     attributes: [NSAttributedString.Key: Any]? = nil) {
        let attributes = attributes ?? [:]
        let text = NSMutableAttributedString(attributedString: mention.attributedString)
        text.addAttributes(attributes)
        let space = NSMutableAttributedString(string: " ", attributes: attributes)
        text.append(space)
        self.replaceText(in: range, with: text)
    }
}
