//
//  EditValueView.swift
//  FBTT
//
//  Created by Christoph on 5/7/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

class EditValueView: UIView {

    let label: UILabel = {
        let label = UILabel.forAutoLayout()
        label.font = UIFont.systemFont(ofSize: 17, weight: .regular)
        label.textColor = UIColor.text.detail
        return label
    }()

    let textView: UITextView = {
        let view = UITextView.forAutoLayout()
        view.backgroundColor = .appBackground
        view.font = UIFont.systemFont(ofSize: 17, weight: .regular)
        view.isEditable = true
        view.isScrollEnabled = false
        view.textColor = UIColor.text.default
        return view
    }()

    init(label: Localized, value: String = "") {
        super.init(frame: .zero)
        self.backgroundColor = .appBackground
        self.label.text = label.text
        self.textView.text = value
        self.addSubviews()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func addSubviews() {

        self.useAutoLayout()
        self.constrainHeight(greaterThanOrEqualTo: 46)

        var insets = UIEdgeInsets(top: 0, left: 21, bottom: 0, right: 0)
        Layout.fillTopLeft(of: self, with: self.label, insets: insets)
        self.label.constrainHeight(to: 46)

        // note that 114 is arbitrary and does not take into account different screen widths
        insets = UIEdgeInsets(top: 10, left: 114, bottom: 0, right: -8)
        Layout.fill(view: self, with: self.textView, insets: insets)
        self.textView.contentInset = .top(-5)
    }
}
