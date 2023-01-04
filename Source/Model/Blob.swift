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

        // swiftlint:disable nesting
        struct Dimensions: Codable {
            let width: Int
            let height: Int
        }
        // swiftlint:enable nesting

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
    
    // MARK: - MIME type
    
    // https://stackoverflow.com/a/32765708/982195
    static func mimeType(for data: Data) -> String {

        var b: UInt8 = 0
        data.copyBytes(to: &b, count: 1)

        switch b {
        case 0xFF:
            return "image/jpeg"
        case 0x89:
            return "image/png"
        case 0x47:
            return "image/gif"
        case 0x4D, 0x49:
            return "image/tiff"
        case 0x25:
            return "application/pdf"
        case 0xD0:
            return "application/vnd"
        case 0x46:
            return "text/plain"
        default:
            return "application/octet-stream"
        }
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
        lhs.identifier == rhs.identifier
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
    }
    var id: BlobIdentifier {
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
