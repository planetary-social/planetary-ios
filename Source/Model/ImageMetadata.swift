//
//  Image.swift
//  FBTTUnitTests
//
//  Created by Christoph on 1/30/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

struct ImageMetadata: Codable {

    let height: Int?
    let link: BlobIdentifier
    let size: Int?
    let type: String?    // mime type enum?
    let width: Int?

    var identifier: BlobIdentifier {
        return self.link
    }
}

extension ImageMetadata {

    init(link: BlobIdentifier) {
        self.height = nil
        self.link = link
        self.size = nil
        self.type = nil
        self.width = nil
    }

    init?(link: BlobIdentifier?) {
        guard let link = link else { return nil }
        self.init(link: link)
    }
}
