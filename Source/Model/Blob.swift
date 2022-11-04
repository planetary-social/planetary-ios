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
    let name: String?

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

    init(identifier: BlobIdentifier, name: String? = nil, metadata: Metadata? = nil) {
        self.identifier = identifier
        self.name = name
        self.metadata = metadata
    }
    
    // MARK: mentions gap
}

typealias Blobs = [Blob]

extension Blob {
    func asMention() -> Mention {
        Mention(link: self.identifier, name: self.name, metadata: self.metadata)
    }
}

extension Blob: Equatable, Hashable, Identifiable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.identifier == rhs.identifier
    }
    func hash(into hasher: inout Hasher) {
        identifier.hash(into: &hasher)
    }
    var id: String {
        identifier
    }
}

extension Blobs {
    func asMentions() -> Mentions {
        self.map {
            $0.asMention()
        }
    }
}
