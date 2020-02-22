//
//  UIScreen+Sizes.swift
//  FBTT
//
//  Created by Zef Houssney on 9/5/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import UIKit

extension UIScreen {
    // use sparingly... avoid where possible.
    var isShort: Bool {
        let height = UIScreen.main.bounds.height
        // using < 600px targets only the iPhone SE/5s, as the iPhone 6 and up starts at 667px tall.
        return height < 600
    }
}
