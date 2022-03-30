//
//  Channel.swift
//  FBTTUnitTests
//
//  Created by Christoph on 1/28/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

@available(*, deprecated)
struct Channel: ContentCodable {

    let type: ContentType = .channel
    let name: String

    init(hashtag: String) {
        self.name = hashtag.withoutHashPrefix
        self.root = nil
    }
}

extension Channel {

    var isModern: Bool {
        self.root != nil
    }

    var hashtag: String {
        "#\(self.name)"
    }
}

extension Channel: Markdownable {

    var markdown: String {
        self.hashtag
    }
}
