//
//  ImageMetadata+UIImage.swift
//  FBTT
//
//  Created by Christoph on 5/8/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

extension ImageMetadata {

    init(link: BlobIdentifier, jpegImage: UIImage, data: Data) {
        self.link = link
        self.width = Int(jpegImage.size.width)
        self.height = Int(jpegImage.size.height)
        self.size = data.count
        self.type = MIMEType.jpeg.rawValue
    }
}
