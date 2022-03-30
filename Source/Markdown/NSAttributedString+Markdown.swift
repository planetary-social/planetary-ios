//
//  NSAttributedString+Markdown.swift
//  Planetary
//
//  Created by Martin Dutra on 4/3/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation

extension NSAttributedString {
    
    func encodeMarkdown() -> String {
        let attributedString = NSMutableAttributedString(attributedString: self)
        attributedString.removeHashtagLinkAttributes()
        attributedString.replaceMentionLinkAttributesWithMarkdown()
        return attributedString.string
    }
}
