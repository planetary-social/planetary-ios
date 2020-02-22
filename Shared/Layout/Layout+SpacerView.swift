//
//  Layout+SpacerView.swift
//  FBTT
//
//  Created by Christoph on 4/11/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

extension Layout {

    @discardableResult
    static func addSpacerView(toTopOf view: UIView, height: CGFloat = UIEdgeInsets.default.top) -> UIView {
        let spacer = UIView.forAutoLayout()
        spacer.constrainHeight(to: height)
        Layout.fillTop(of: view, with: spacer, insets: .zero)
        return spacer
    }

    static func addSpacerViewFromBottomOfSuperview(toBottomOf peerView: UIView) {
        guard let superview = peerView.superview else { return }
        let spacer = UIView.forAutoLayout()
        spacer.setContentHuggingPriority(.defaultLow, for: .vertical)
        spacer.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)
        superview.addSubview(spacer)
        spacer.pinTop(toBottomOf: peerView)
        spacer.pinBottomToSuperviewBottom()
    }
}
