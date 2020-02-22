//
//  UINavigationBar+Verse.swift
//  Planetary
//
//  Created by Christoph on 10/11/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

extension UINavigationBar {

    func showBottomSeparator() {
        Layout.addSeparator(toBottomOf: self, color: UIColor.separator.bar)
    }
}
