//
//  Draft.swift
//  Planetary
//
//  Created by Martin Dutra on 10/20/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

/// A class representing a drafted post. Supports NSCoding so it can be saved to disk.
class Draft: NSObject, NSCoding {
    
    var attributedText: NSAttributedString?
    var images: [UIImage] = []
    
    init(attributedText: NSAttributedString?, images: [UIImage]) {
        self.attributedText = attributedText
        self.images = images
    }
    
    // swiftlint:disable legacy_objc_type
    required init?(coder: NSCoder) {
        self.attributedText = coder.decodeObject(of: NSAttributedString.self, forKey: "attributedText")
        self.images = (coder.decodeObject(of: NSArray.self, forKey: "images") as? [UIImage]) ?? []
    }
    
    func encode(with coder: NSCoder) {
        coder.encode(attributedText, forKey: "attributedText")
        coder.encode(images, forKey: "images")
    }
    // swiftlint:enable legacy_objc_type
}
