//
//  Blob+NSAttributedString.swift
//  FBTT
//
//  Created by Christoph on 8/23/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

extension NSAttributedString {

    func blobsAndRanges() -> [(Blob, NSRange)] {
        var results: [(Blob, NSRange)] = []
        let range = NSRange(location: 0, length: self.length)
        self.enumerateAttribute(NSAttributedString.Key.link,
                                in: range,
                                options: []) {
            attribute, range, _ in
            guard let identifier = attribute as? BlobIdentifier, identifier.isBlob else { return }
            let name = self.attributedSubstring(from: range).string
            let blob = Blob(identifier: identifier, name: name)
            results += [(blob, range)]
        }
        return results
    }

    func blobs() -> [Blob] {
        let results = self.blobsAndRanges()
        let blobs = results.map { $0.0 }
        return blobs
    }
}
