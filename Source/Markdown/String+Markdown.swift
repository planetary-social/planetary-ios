//
//  String+Markdown.swift
//  Planetary
//
//  Created by Martin Dutra on 4/3/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation
import Down

extension String {
    
    func decodeMarkdown() -> NSAttributedString {
        let down = Down(markdownString: self)
        let styler = MarkdownStyler()
        do {
            let attributedString = try down.toAttributedString(.default,
                                                               styler: styler)
            let mutableAttributedString = NSMutableAttributedString(attributedString: attributedString)
            let hashtags = attributedString.string.hashtagsWithRanges()
            for (hashtag, range) in hashtags.reversed() {
                let attributedHashtag = attributedString.attributedSubstring(from: range)
                let mutableAttributedHashtag = NSMutableAttributedString(attributedString: attributedHashtag)
                styler.style(link: mutableAttributedHashtag, title: hashtag.string, url: hashtag.string)
                mutableAttributedString.replaceCharacters(in: range, with: mutableAttributedHashtag)
            }
            
            return mutableAttributedString
        } catch let error {
            Log.optional(error)
            CrashReporting.shared.reportIfNeeded(error: error)
            return NSAttributedString(string: self)
        }
    }
    
}
