//
//  UINavigationController+Back.swift
//  Planetary
//
//  Created by Martin Dutra on 17/11/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import UIKit

extension UINavigationController {
    // Remove back button text
    override open func viewWillLayoutSubviews() {
        navigationBar.topItem?.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
    }
}
