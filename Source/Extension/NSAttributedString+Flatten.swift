//
//  NSAttributedString+Flatten.swift
//  Planetary
//
//  Created by Christoph on 12/17/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

extension NSAttributedString {

    /// Returns a normalized string that has stripped all the Planetary
    /// specific attributions and styling.  Recall that a Post.text attributed string
    /// will have decorations for mentions, links, etc that need to be removed.
    func flattenedString() -> String {
        let mas = self.mutable()
        mas.replaceMentionLinkAttributesWithNamesOnly()
        mas.removeAllAttributes()
        return mas.string
    }
}
