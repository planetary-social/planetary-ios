//
//  UIBarButtonItem+Saveable.swift
//  FBTT
//
//  Created by Christoph on 5/15/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

extension UIBarButtonItem {

    static func `for`(_ saveable: Saveable, title: Localized = .save) -> UIBarButtonItem {
        let item = UIBarButtonItem(title: title.text, style: .plain, target: saveable, action: #selector(saveable.save))
        item.isEnabled = saveable.isReadyToSave
        return item
    }
}
