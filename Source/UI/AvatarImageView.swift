//
//  AvatarImageView.swift
//  FBTT
//
//  Created by Christoph on 8/1/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit
import Logger
import Secrets

class AvatarImageView: ImageView {
    
    @MainActor override var image: UIImage? {
        get {
            super.image
        }
        set {
            super.image = newValue ?? UIImage.verse.missingAbout
        }
    }

    convenience init() {
        self.init(image: UIImage.verse.missingAbout)
        self.contentMode = .scaleAspectFill
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.round()
    }
}
