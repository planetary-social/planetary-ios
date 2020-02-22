//
//  UIScrollView+Default.swift
//  FBTT
//
//  Created by Christoph on 4/11/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

extension UIScrollView {

    static func `default`() -> UIScrollView {
        let scrollView = UIScrollView.forAutoLayout()
        scrollView.clipsToBounds = false
        return scrollView
    }
}
