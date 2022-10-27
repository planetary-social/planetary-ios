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
        view.textColor = UIColor.text.default
        view.layer.borderColor = UIColor.border.text.cgColor
        view.layer.borderWidth = 1
        view.roundedCorners(radius: 8)
        view.textContainerInset = .defaultText
        return view
    }()
    
    let textField: TextFieldWithInsets = {
        let textField = TextFieldWithInsets()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.layer.borderWidth = 1
        textField.layer.borderColor = UIColor.border.text.cgColor
        textField.roundedCorners(radius: 8)
        return textField
    }()
    
    private let inputType: Localized
    
    var bottomConstraint: NSLayoutConstraint?

    init(label: Localized, value: String = "") {
        self.inputType = label
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

        let labelInsets = UIEdgeInsets.topLeft
        label.setContentHuggingPriority(.defaultHigh, for: .vertical)
        Layout.fillTop(of: self, with: label, insets: labelInsets)
        
        let textInputInsets = UIEdgeInsets.topLeftRight
        switch inputType {
            case .name:
                textField.setContentHuggingPriority(.defaultHigh, for: .vertical)
                Layout.fillSouth(of: label, with: textField, insets: textInputInsets)
                bottomConstraint = textField.pinBottomToSuperviewBottom(constant: -Layout.verticalSpacing, respectSafeArea: false)
            case .bio:
                textView.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)
                Layout.fillSouth(of: label, with: textView, insets: textInputInsets)
                bottomConstraint = textView.pinBottomToSuperviewBottom(constant: -Layout.verticalSpacing, respectSafeArea: false)
            default:
                break
        }
    }
}
