//
//  AvatarStackView.swift
//  Planetary
//
//  Created by Christoph on 12/4/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

class AvatarStackView: UIView {

    let height: CGFloat = 20
    let overlap: CGFloat = 6
    let maxCount = 3

    var abouts: [About] = [] {
        didSet {
            self.loadAvatars()
        }
    }

    init() {
        super.init(frame: CGRect.zero)
        self.useAutoLayout()
    }

    func loadAvatars() {
        self.subviews.forEach { $0.removeFromSuperview() }

        var previousView: AvatarImageView?
        let max = min(self.abouts.count, self.maxCount)

        let abouts = self.abouts.sorted(by: { $0.image != nil && $1.image == nil }).prefix(upTo: max)

        for about in abouts {
            let view = AvatarImageView()
            view.useAutoLayout()

            view.layer.borderColor = UIColor.appBackground.cgColor
            view.layer.borderWidth = 1

            view.set(image: about.image)
            view.constrainSize(to: height)

            if let previousView = previousView {
                self.addSubview(view)
                view.constrainTop(toTopOf: previousView)
                view.constrainLeading(toTrailingOf: previousView, constant: -self.overlap)
            } else {
                Layout.fillLeft(of: self, with: view)
            }

            if about == abouts.last {
                view.constrainTrailingToSuperview()
            }
            previousView = view
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
