//
//  Hashtag+Link.swift
//  Planetary
//
//  Created by Martin Dutra on 5/25/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation

extension Hashtag {

    var publicLink: URL? {
        URL(string: "https://planetary.link/\(self.string)")
    }

    static func parse(publicLink: URL) -> Hashtag? {
        if publicLink.path == "/", let fragment = publicLink.fragment {
            return Hashtag.named(fragment)
        }
        return nil
    }
}
