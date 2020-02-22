//
//  ProfileButton.swift
//  FBTT
//
//  Created by Christoph on 6/28/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

class AvatarButton: ImageButton {

    convenience init() {
        self.init(type: .custom)
        self.useAutoLayout()
        self.contentMode = .scaleAspectFill
        self.imageView?.contentMode = .scaleAspectFill
        self.setImage(UIImage.verse.missingAbout, for: .normal)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.round()
    }

    func setImageForMe() {
        self.reset()
        Bots.current.about() {
            [weak self] about, _ in
            self?.setImage(for: about)
        }
    }

    func setImage(for about: About?) {
        self.reset()
        guard let image = about?.image else { return }
        self.set(image: image)
    }

    func reset() {
        self.setImage(UIImage.verse.missingAbout, for: .normal)
    }
}
