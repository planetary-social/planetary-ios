//
//  Post+Blob.swift
//  FBTT
//
//  Created by Christoph on 9/6/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

extension Post {

    // Returns the serialized blobs or inline blobs, in order.
    var anyBlobs: Blobs {
        guard let blobs = self.mentions?.asBlobs(), !blobs.isEmpty else { return self.inlineBlobs }
        return blobs
    }

    var hasBlobs: Bool {
        self.anyBlobs.isEmpty == false
    }

    /// Returns a mutated copy of the current post but with
    /// the blobs property.  This is required to be able to
    /// publish a post with associated images or binary content.
    func copy(with blobs: Blobs) -> Post {
        var textWithImages = self.text

        if blobs.count > 0 {
            // This is meant as compat with other ssb-clients like Patchwork, etc.
            textWithImages += "\n"
            for (i, b) in blobs.enumerated() {
                // TODO: captionize!
                textWithImages += "\n![planetary attachment no.\(i + 1)](\(b.identifier))"
            }
        }

        return Post(blobs: blobs,
                    branches: self.branch,
                    mentions: self.mentions,
                    root: self.root,
                    text: textWithImages)
    }
}

extension String {
    func withoutGallery() -> String {
        guard let attMatch = self.range(of: "\n![planetary attachment no.1") else {
            return self
        }
        let before = self[self.startIndex..<attMatch.lowerBound]
        return String(before)
    }
}
