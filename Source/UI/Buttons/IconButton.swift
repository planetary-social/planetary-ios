//
//  IconButton.swift
//  Planetary
//
//  Created by Zef Houssney on 10/10/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import UIKit

// A button class for icon-only buttons
class IconButton: AppButton {
    var image: UIImage? {
        didSet {
            self.setImage(self.image, for: .normal)
        }
    }

    var highlightedImage: UIImage? {
        didSet {
            self.setImage(self.highlightedImage, for: .highlighted)
        }
    }

    init(icon: UIImage?) {
        super.init()
        self.imageView?.contentMode = .scaleAspectFill
        self.setImage(icon, for: .normal)
        self.adjustsImageWhenHighlighted = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
