//
//  Layout+ContentView.swift
//  FBTT
//
//  Created by Christoph on 3/21/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

extension Layout {

    static func scrollView(in viewController: UIViewController) -> UIScrollView {
        let scrollView = UIScrollView.default()
        self.fill(view: viewController.view, with: scrollView)
        return scrollView
    }

    static func verticalContentView(in scrollView: UIScrollView) -> UIView {
        let contentView = UIView.forAutoLayout()
        Layout.fill(scrollView: scrollView, with: contentView, scrollable: false)
        return contentView
    }

    static func scrollViewWithContentView(in viewController: UIViewController) -> (UIScrollView, UIView) {
        let scrollView = Layout.scrollView(in: viewController)
        let contentView = Layout.verticalContentView(in: scrollView)
        return (scrollView, contentView)
    }

    static func fill(scrollView: UIScrollView, with contentView: UIView, scrollable: Bool = true) {
        Layout.fill(view: scrollView, with: contentView, respectSafeArea: !scrollable)
        contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor).isActive = true
    }
}
