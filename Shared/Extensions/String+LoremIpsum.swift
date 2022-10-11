//
//  String+LoremIpsum.swift
//  Planetary
//
//  Created by Martin Dutra on 7/10/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation

extension String {

    static func loremIpsum(_ numberOfLines: Int) -> String {
        let lines = [
            "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.",
            "Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.",
            "Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur.",
            "Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."
        ]
        return lines.prefix(numberOfLines).joined(separator: " ")
    }

    static func loremIpsum(words: Int) -> String {
        let sample = [
            "Lorem",
            "ipsum",
            "dolor",
            "sit",
            "amet",
            "consectetur",
            "adipiscing",
            "elit",
            "sed",
            "do",
            "eiusmod",
            "tempor",
            "incididunt",
            "ut",
            "labore",
            "et",
            "dolore",
            "magna",
            "aliqua"
        ]
        return sample.prefix(words).joined(separator: " ")
    }
}
