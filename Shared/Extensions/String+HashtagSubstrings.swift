//
//  String+HashtagSubstrings.swift
//  FBTT
//
//  Created by Christoph on 7/7/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

extension String {

    // Matches alphanumeric hashtags that have at least one alpha character.
    // Developed and tested with https://regex101.com
    //
    // # - first required character
    // [a-zA-Z] - alphabet only
    // [a-zA-Z-\\d] - alphanumeric and the dash
    // [a-zA-Z][a-zA-Z-\\d] - mixed alphanumeric and the dash
    // ([a-zA-Z\\d]|$) - ending with non-alphanumeric or end of input
    private static let alphanumericHashtagRegex = "#[a-zA-Z]*[a-zA-Z-\\d]*[a-zA-Z][a-zA-Z-\\d]*([a-zA-Z\\d]|$)"

    func hashtagSubstringsWithRanges() -> [(String, NSRange)] {
        guard let regex = try? NSRegularExpression(pattern: String.alphanumericHashtagRegex, options: []) else {
            return []
        }

        let string = self as NSString
        let results = regex.matches(in: self,
                                    options: [],
                                    range: NSRange(location: 0, length: string.length))

        // extract substrings and ranges
        let substringsAndRanges = results.map { (string.substring(with: $0.range), $0.range) }

        // trim trailing space and adjust range
        let trimmedAndRanges: [(String, NSRange)] = substringsAndRanges.map {
            let trimmed = $0.0
            var range = $0.1
            range.length -= (range.length - trimmed.count)
            return (trimmed, range)
        }

        // done
        return trimmedAndRanges
    }

    func hashtagSubstrings() -> [String] {
        let results = self.hashtagSubstringsWithRanges()
        let hashtags = results.map { $0.0 }
        return hashtags
    }
}
