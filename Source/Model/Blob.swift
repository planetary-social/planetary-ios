//
//  Blob.swift
//  FBTT
//
//  Created by Christoph on 8/23/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

struct Blob: Codable {

    // MARK: Required properties

    let identifier: BlobIdentifier
    let name: String

    // MARK: Optional metadata

    struct Metadata: Codable {

        struct Dimensions: Codable {
            let width: Int
            let height: Int
        }

        // optional metadata
        let averageColorRGB: Int?
        let dimensions: Dimensions?
        let mimeType: String?
        let numberOfBytes: Int?

        // future metadata
        // duration
        // area of interest (rectangle)
    }

    let metadata: Metadata?

    // MARK: Lifecycle

    init(identifier: BlobIdentifier, name: String = "blob", metadata: Metadata? = nil) {
        self.identifier = identifier
        self.name = name
        self.metadata = metadata
    }
}

typealias Blobs = [Blob]
