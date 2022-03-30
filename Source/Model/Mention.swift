//
//  Mention.swift
//  FBTT
//
//  Created by Christoph on 1/22/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

struct Mention: Codable {

    let link: Identifier
    let name: String?

    var identity: Identifier {
        self.link
    }
    
    // optional
    let size: Int? // filesize in bytes
    let width: Int?
    let height: Int?
    let type: String?
    
    // just for hashtags
//    init(link: String) {
//        self.link = link
//        
//        // empty
//        self.name = nil
//        self.size = nil
//        self.width = nil
//        self.height = nil
//        self.type = nil
//    }
    
    init(link: Identifier, name: String? = nil, metadata: Blob.Metadata? = nil) {
        self.link = link
        self.name = name

        if let m = metadata {
            self.size = m.numberOfBytes
            self.width = m.dimensions?.width
            self.height = m.dimensions?.height
            self.type = m.mimeType
        } else {
            self.size = nil
            self.width = nil
            self.height = nil
            self.type = nil
        }
    }
}

extension Mention: Markdownable {

    var markdown: String {
        guard let name = self.name else { return "" }
        return "[\(name)](\(self.link))"
    }
}

typealias Mentions = [Mention]

extension Mentions {

    func identities() -> [Identity] {
        self.map { $0.identity }
    }

    func markdowns() -> [String] {
        self.map { $0.markdown }
    }
}

extension Mentions {
    func asBlobs() -> Blobs {
        self.filter {
            $0.link.isBlob
        }.map {
            var dims: Blob.Metadata.Dimensions?
            let w = $0.width ?? 0
            let h = $0.height ?? 0
            if w != 0 && h != 0 {
                dims = Blob.Metadata.Dimensions(width: w, height: h)
            }
            let meta = Blob.Metadata(averageColorRGB: nil, dimensions: dims, mimeType: $0.type, numberOfBytes: $0.size)
            return Blob(identifier: $0.link, name: $0.name, metadata: meta)
        }
    }
}
