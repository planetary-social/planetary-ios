//
//  UIButton+Text.swift
//  FBTT
//
//  Created by Zef Houssney on 8/21/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import UIKit

extension UIButton {
    func setText(_ text: Text) {
        setTitle(text.text, for: .normal)
    }

    func setText(_ text: Text.Onboarding) {
        setTitle(text.text, for: .normal)
    }
}
