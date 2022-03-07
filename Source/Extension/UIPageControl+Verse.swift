//
//  UIPageControl+Verse.swift
//  FBTT
//
//  Created by Christoph on 9/5/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

extension UIPageControl {

    static func `default`() -> UIPageControl {
        let control = UIPageControl.forAutoLayout()
        control.addBackgroundView()
        control.currentPageIndicatorTintColor = UIColor.tint.default
        control.pageIndicatorTintColor = .white
        return control
    }

    /// Adds a rounded matte background to the control.  This is
    /// constrained to resize as the control resizes, so no additional
    /// layout work should be required.
    private func addBackgroundView() {
        let view = UIView.forAutoLayout()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.25)
        view.isUserInteractionEnabled = false
        self.addSubview(view)
        view.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
        view.centerYAnchor.constraint(equalTo: self.centerYAnchor, constant: 0).isActive = true
        view.constrainHeight(to: 13)
        view.widthAnchor.constraint(equalTo: self.widthAnchor, constant: 7).isActive = true
        view.roundedCorners(radius: 6.5)
    }
}
