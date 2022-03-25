//
//  NSMutableAttributedString+Channel.swift
//  FBTT
//
//  Created by Christoph on 7/7/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

extension NSMutableAttributedString {

    convenience init(from channel: Channel) {
        self.init(string: channel.hashtag)
        let range = NSRange(location: 0, length: channel.hashtag.count)
        self.addAttribute(NSAttributedString.Key.link, value: channel.hashtag, range: range)
    }
}

extension Channel {

    var attributedString: NSMutableAttributedString {
        NSMutableAttributedString(from: self)
    }
}

extension NSMutableAttributedString {

    @discardableResult
    func replaceHashtagsWithChannelLinkAttributes() -> NSMutableAttributedString {
        let results = self.string.hashtagsWithRanges()
        for result in results.reversed() {
            let channel = Channel(hashtag: result.0.name)
            self.replaceCharacters(in: result.1, with: channel.attributedString)
        }
        return self
    }

    @discardableResult
    func replaceChannelLinkAttributesWithHashtags() -> NSMutableAttributedString {
        let results = self.channelsWithRanges()
        for result in results.reversed() {
            self.removeAttribute(.link, range: result.1)
        }
        return self
    }
}

extension NSAttributedString {

    func channels() -> [Channel] {
        let results = self.channelsWithRanges()
        let channels = results.map { $0.0 }
        return channels
    }

    func channelsWithRanges() -> [(Channel, NSRange)] {
        var results: [(Channel, NSRange)] = []
        let range = NSRange(location: 0, length: self.length)
        self.enumerateAttribute(NSAttributedString.Key.link,
                                in: range,
                                options: []) {
            attribute, range, _ in
            guard attribute != nil else { return }
            let name = self.attributedSubstring(from: range).string
            guard name.isHashtag else { return }
            let channel = Channel(hashtag: name)
            results += [(channel, range)]
        }
        return results
    }
}
