//
//  Mention.swift
//  FBTT
//
//  Created by Christoph on 1/22/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

struct Mention: Codable {

    let link: Identity
    let name: String

    var identity: Identity {
        return self.link
    }
}

extension Mention: Markdownable {

    var markdown: String {
        var markdown = "[\(self.name)]"
        markdown += "(\(self.link))"
        return markdown
    }
}

typealias Mentions = [Mention]

extension Mentions {

    func identities() -> Identities {
        return self.map { $0.identity }
    }

    func markdowns() -> [String] {
        return self.map { $0.markdown }
    }
}
