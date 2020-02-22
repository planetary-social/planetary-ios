//
//  UIImageView+Fade.swift
//  Planetary
//
//  Created by Zef Houssney on 10/16/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import UIKit

extension UIImageView {

    func fade(to image: UIImage?, duration: TimeInterval = 0.5) {
        UIView.transition(with: self,
                          duration: duration,
                          options: .transitionCrossDissolve,
                          animations: { self.image = image },
                          completion: nil)
    }
}
