//
//  Blob+String.swift
//  Planetary
//
//  Created by Christoph on 12/17/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

extension String {

    /// Matches `![name](identifier)` only, and will likely skip if there are `\` in the name range.
    private static let inlineBlobRegex = #"!\[.+\]\(&[A-Za-z0-9\/+]{43}=\.[\w\d]+\)"#

    // TODO https://app.asana.com/0/914798787098068/1154472587426507/f
    // TODO improve to handle alt text
    /// Returns an array of (String, NSRange) pairs denoting the blob identifiers in this string.
    func blobSubstringsAndRanges() -> [(String, NSRange)] {

        guard let regex = try? NSRegularExpression(pattern: String.inlineBlobRegex, options: []) else {
            return []
        }

        let string = self as NSString
        let results = regex.matches(in: self,
                                    options: [],
                                    range: NSRange(location: 0, length: string.length))

        // extract substrings and ranges
        let substringsAndRanges = results.map {
            (string.substring(with: $0.range), $0.range)
        }

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

    func blobsAndRanges() -> [(Blob, NSRange)] {
        let results = self.blobSubstringsAndRanges()
        let blobsAndRanges: [(Blob, NSRange)] = results.compactMap {
            guard let blob = Blob(inlineBlobString: $0.0) else { return nil }
            return (blob, $0.1)
        }
        return blobsAndRanges
    }

    func blobs() -> Blobs {
        let results = self.blobsAndRanges()
        let blobs = results.map { $0.0 }
        return blobs
    }
}

extension Blob {

    static func name(from string: String) -> String? {
        guard let range = string.range(of: #"!\[(.+)\]"#, options: .regularExpression) else { return nil }
        let substring = String(string[range])
        let start = substring.index(substring.startIndex, offsetBy: 2)
        let end = substring.index(substring.endIndex, offsetBy: -1)
        let name = String(substring[start..<end])
        return name
    }

    static func identifier(from string: String) -> String? {
        guard let range = string.range(of: #"\(&[A-Za-z0-9\/+]{43}=\.[\w\d]+\)"#, options: .regularExpression) else { return nil }
        let substring = String(string[range])
        let start = substring.index(substring.startIndex, offsetBy: 1)
        let end = substring.index(substring.endIndex, offsetBy: -1)
        let identifier = String(substring[start..<end])
        guard identifier.isBlob else { return nil }
        return identifier
    }

    init?(inlineBlobString string: String) {
        guard let name = Blob.name(from: string) else { return nil }
        guard let identifier = Blob.identifier(from: string) else { return nil }
        self.init(identifier: identifier, name: name)
    }
}
