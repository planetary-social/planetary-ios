//
//  NSAttributedString+Truncation.swift
//  FBTT
//
//  Created by Zef Houssney on 9/19/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import UIKit

// over - the number of lines that must be exceeded for the post to be truncated at all
// to - the number of lines that will be used for truncation when a post is truncated
//
// having both of these prevents small truncations from taking place, where you expand and see only a couple extra words
//
/// IMPORTANT!
/// This setting is greatly affected by the length of the string.  In the case of the Home screen,
/// all `Post.text` is truncated via the `PostTruncatedTextCache`.  This is because the measuring
/// that happens in `NSAttributedString.truncating()` is EXTREMELY EXPENSIVE.  And since
/// only a few lines of the post are shown, there is no reason to measure the entire string.  That said, when
/// selecting the `TruncationSettings` for your particular view, be mindful of the actual length of this
/// string.  Using truncated strings will always be faster than using the full string.  In practice on an iPhone 11 Pro,
/// measuring a 3000 character string for display in a table view would cause scrolling to stall.
typealias TruncationSettings = (over: Int, to: Int)

extension NSAttributedString {

    // this truncates text to a given number of lines based on the space available
    // the truncationText is a custom attributed string that will be used when the text is truncated
    // if there is enough room available, the original string will be returned unmodified.
    func truncating(with truncationText: NSAttributedString, settings: TruncationSettings, width: CGFloat) -> NSAttributedString {

        let size = CGSize(width: width, height: .greatestFiniteMagnitude)
        let lineHeight = self.boundingRect(with: size, options: [], context: nil).size.height
        let targetHeight = lineHeight * CGFloat(settings.over)

        // IMPORTANT!
        // NSAttributedString.boundingRect() is VERY EXPENSIVE!
        // we're already fitting within a good size
        let boundingRect = self.boundingRect(with: size, options: .usesLineFragmentOrigin, context: nil)
        if boundingRect.size.height < targetHeight {
            return self
        }

        let truncationHeight = lineHeight * CGFloat(settings.to) + 5

        let string = self.string
        // each wordBound represents the needed data to get from the start of a word to the end of the whitespace/word boundary after it
        var wordBounds = [(start: Int, length: Int)]()
        var lastEnd = string.startIndex
        string.enumerateSubstrings(in: string.startIndex..<string.endIndex, options: .byWords) { (_, range, enclosingRange, _) in
            let start = string.distance(from: string.startIndex, to: lastEnd)
            // normally, whitespace and punctuation are captured with the word following the whitespace
            // however, at the end of the string we must capture any trailing punctuation
            // so we use the enclosingRange for those cases, which includes the trailing whitespace and punctuation
            let upperBound = enclosingRange.upperBound == string.endIndex ? enclosingRange.upperBound : range.upperBound
            let length = string.distance(from: lastEnd, to: upperBound)
            wordBounds.append((start, length))
            lastEnd = range.upperBound
        }

        let truncatedString = NSMutableAttributedString(attributedString: self)
        truncatedString.append(truncationText)

        for bound in wordBounds.reversed() {
            truncatedString.deleteCharacters(in: NSRange(location: bound.start, length: bound.length))
            let boundingSize = truncatedString.boundingRect(with: size, options: .usesLineFragmentOrigin, context: nil).size
            if boundingSize.height <= truncationHeight {
                return truncatedString
            }
        }
        return truncatedString
    }
}
