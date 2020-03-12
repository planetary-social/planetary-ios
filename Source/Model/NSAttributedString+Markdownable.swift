//
//  NSAttributedString+Markdownable.swift
//  FBTT
//
//  Created by Christoph on 6/17/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

extension NSAttributedString: Markdownable {

    /// Returns a String that has transcoded all the attributes into
    /// markdown.  Because the ranges are for the string in it's current
    /// form, if the attributes are replaced from beginning to end, the
    /// later ranges will be invalided by the previous insertions.  So,
    /// the attributes are iterated in reverse order.
    var markdown: String {
        let string = NSMutableAttributedString(attributedString: self)
//        string.removeCompatabilityAttachmentLinks()
        string.removeHashtagLinkAttributes()
        string.replaceMentionLinkAttributesWithMarkdown()
        return string.string
    }
}
