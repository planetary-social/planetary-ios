//
//  Hashtag+NSAttributedString.swift
//  FBTT
//
//  Created by Christoph on 7/11/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

extension NSMutableAttributedString {

    convenience init(from hashtag: Hashtag) {
        self.init(string: hashtag.string)
        let range = NSRange(location: 0, length: hashtag.string.count)
        self.addAttribute(NSAttributedString.Key.link, value: hashtag.string, range: range)
    }
}

extension Hashtag {

    var attributedString: NSMutableAttributedString {
        NSMutableAttributedString(from: self)
    }
}

extension NSMutableAttributedString {

    @discardableResult
    func replaceHashtagsWithLinkAttributes() -> NSMutableAttributedString {
        let results = self.string.hashtagsWithRanges()
        for result in results.reversed() {
            self.replaceCharacters(in: result.1, with: result.0.attributedString)
        }
        return self
    }

    @discardableResult
    func removeHashtagLinkAttributes() -> NSMutableAttributedString {
        let results = self.hashtagsWithRanges()
        for result in results.reversed() {
            self.removeAttribute(.link, range: result.1)
        }
        return self
    }
}

extension NSAttributedString {

    func hashtags() -> [Hashtag] {
        let results = self.hashtagsWithRanges()
        let hashtags = results.map { $0.0 }
        return hashtags
    }

    func hashtagsWithRanges() -> [(Hashtag, NSRange)] {
        var results: [(Hashtag, NSRange)] = []
        let range = NSRange(location: 0, length: self.length)
        self.enumerateAttribute(NSAttributedString.Key.link,
                                in: range,
                                options: []) {
            attribute, range, _ in
            guard attribute != nil else { return }
            let name = self.attributedSubstring(from: range).string
            guard name.isHashtag else { return }
            let hashtag = Hashtag.named(name)
            results += [(hashtag, range)]
        }
        return results
    }
}
