//
//  Hashtag+String.swift
//  FBTT
//
//  Created by Christoph on 7/11/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

extension String {

    func hashtagsWithRanges() -> [(Hashtag, NSRange)] {
        let stringsAndRanges = self.hashtagSubstringsWithRanges()
        let hashtagsAndRanges = stringsAndRanges.map { (Hashtag.named($0.0), $0.1) }
        return hashtagsAndRanges
    }

    func hashtags() -> [Hashtag] {
        let strings = self.hashtagSubstrings()
        let hashtags = strings.map { Hashtag.named($0) }
        return hashtags
    }
}
