//
//  UISwitch+Verse.swift
//  FBTT
//
//  Created by Christoph on 8/12/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

extension UISwitch {

    static func `default`() -> UISwitch {
        let toggle = UISwitch.forAutoLayout()
        toggle.onTintColor = UIColor.tint.default
        return toggle
    }
}
