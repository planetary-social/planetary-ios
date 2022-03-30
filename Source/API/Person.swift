//
//  User.swift
//  FBTT
//
//  Created by Christoph on 6/6/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

struct Person: Codable, Equatable {

    let bio: String?
    let id: String
    let identity: Identity
    let image: String?
    let image_url: String?
    let in_directory: Bool?
    let name: String
    let shortcode: String?

    var attributedBio: NSAttributedString {
        self.bio?.decodeMarkdown() ?? NSAttributedString()
    }

    static func == (lhs: Person, rhs: Person) -> Bool {
        lhs.id == rhs.id
    }
}

extension Person: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(self.identity)
    }
}
