//
//  Blob+UIImage.swift
//  FBTT
//
//  Created by Christoph on 9/6/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

extension Blob.Metadata {

    static func describing(_ image: UIImage,
                           mimeType: MIMEType? = nil,
                           data: Data? = nil) -> Blob.Metadata {
        Blob.Metadata(averageColorRGB: image.averageColor()?.rgb,
                             dimensions: Dimensions(image.size),
                             mimeType: mimeType?.rawValue,
                             numberOfBytes: data?.count ?? 0)
    }
}

extension Blob.Metadata.Dimensions {

    init(_ size: CGSize) {
        self.width = Int(size.width)
        self.height = Int(size.height)
    }
}
