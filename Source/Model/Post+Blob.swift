//
//  Post+Blob.swift
//  FBTT
//
//  Created by Christoph on 9/6/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

extension Post {

    /// Returns blobs extracted from the post's markdown.
    var inlineBlobs: Blobs {
        return self.text.blobs()
    }

    // Returns the serialized blobs or inline blobs, in order.
    var anyBlobs: Blobs {
        guard let blobs = self.mentions?.asBlobs(), !blobs.isEmpty else { return self.inlineBlobs }
        return blobs
    }

    var hasBlobs: Bool {
        return self.anyBlobs.isEmpty == false
    }

    /// Returns a mutated copy of the current post but with
    /// the blobs property.  This is required to be able to
    /// publish a post with associated images or binary content.
    func copy(with blobs: Blobs) -> Post {
        return Post(blobs: blobs,
                    branches: self.branch,
                    hashtags: self.hashtags,
                    mentions: self.mentions,
                    root: self.root,
                    text: self.text)
    }
}
