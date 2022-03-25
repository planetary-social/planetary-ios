//
//  UIView+AutoLayout.swift
//  FBTT
//
//  Created by Christoph on 2/14/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

extension UIView {

    static func forAutoLayout() -> Self {
        let view = self.init()
        return view.useAutoLayout()
    }

    @discardableResult
    func useAutoLayout() -> Self {
        self.translatesAutoresizingMaskIntoConstraints = false
        return self
    }
}
