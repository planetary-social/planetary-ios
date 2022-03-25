//
//  OnboardingStepView.swift
//  FBTT
//
//  Created by Christoph on 7/15/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

class OnboardingStepView: UIView, UITextViewDelegate, UITextFieldDelegate {

    enum ButtonStyle {
        case verticalStack, horizontalStack

        var stackAxis: NSLayoutConstraint.Axis {
            self == .verticalStack ? .vertical : .horizontal
        }

        var spacing: CGFloat {
            var spacing = Layout.spacing(stackAxis)
            if self == .verticalStack {
                spacing -= 10
            }
            return spacing
        }

        var requiresSpacer: Bool {
            self == .horizontalStack
        }

        var buttonHeight: CGFloat {
            switch self {
            case .verticalStack:
                return 40
            case .horizontalStack:
                return 36
            }
        }
    }

    let titleLabel: UILabel = {
        let label = UILabel.forAutoLayout()
        label.font = UIFont.systemFont(ofSize: 25, weight: .semibold)
        label.numberOfLines = 0
        label.textAlignment = .center
        label.textColor = UIColor.tint.default
        return label
    }()

    private lazy var _textField: UITextField = {
        let view = UITextField.forAutoLayout()
        view.delegate = self
        view.addTarget(self, action: #selector(_textFieldValueDidChange(textField:)), for: .editingChanged)
        view.font = UIFont.systemFont(ofSize: 22, weight: .medium)
        view.isHidden = true
        view.layer.borderColor = UIColor.border.text.cgColor
        view.layer.borderWidth = 1
        view.layer.cornerRadius = 10
        view.text = ""
        view.textAlignment = .center
        return view
    }()

    private lazy var _textView: UITextView = {
        let view = UITextView.forAutoLayout()
        view.delegate = self
        view.font = UIFont.systemFont(ofSize: 19, weight: .medium)
        view.isHidden = true
        view.isScrollEnabled = true
        view.layer.borderColor = UIColor.border.text.cgColor
        view.layer.borderWidth = 1
        view.layer.cornerRadius = 10
        view.textContainerInset = UIEdgeInsets(top: Layout.verticalSpacing, left: 11, bottom: Layout.verticalSpacing, right: 11)
        return view
    }()

    let hintLabel: UILabel = {
        let label = UILabel.forAutoLayout()
        label.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()

    private lazy var _secondaryButton: UIButton = {
        let button = UIButton(type: .system)
        button.addTarget(self, action: #selector(_secondaryButtonTouchUpInside(button:)), for: .touchUpInside)
        button.isHidden = true
        button.setText(.skip)
        button.setTitleColor(UIColor.tint.default, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        button.useAutoLayout()
        button.contentEdgeInsets = .pillButton
        return button
    }()

    private lazy var _primaryButton: UIButton = {
        let button = UIButton(type: .custom)
        button.addTarget(self, action: #selector(_primaryButtonTouchUpInside(button:)), for: .touchUpInside)
        let image = UIColor.tint.default.image().resizableImage(withCapInsets: .zero)
        button.setBackgroundImage(image, for: .normal)
        button.setText(.next)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        button.contentEdgeInsets = .pillButton
        return button
    }()

    // MARK: Constraints

    public var titleLabelTopConstraint: NSLayoutConstraint?
    public var textViewTopConstraint: NSLayoutConstraint?
    private var hintLabelToTitleLabelConstraint: NSLayoutConstraint?
    private var hintLabelToTextFieldConstraint: NSLayoutConstraint?
    private var hintLabelToTextViewConstraint: NSLayoutConstraint?

    // MARK: Calculated properties

    /// When a subclass calls this property, it signals that
    /// the view should be displayed vs the other input view.
    /// So, the view is made visible and the hint label top
    /// constraint is adjusted.
    var textField: UITextField {
        self.hintLabelToTitleLabelConstraint?.isActive = false
        self._textField.isHidden = false
        self.hintLabelToTextFieldConstraint?.isActive = true
        self._textView.isHidden = true
        self.hintLabelToTextViewConstraint?.isActive = false
        return self._textField
    }

    /// When a subclass calls this property, it signals that
    /// the view should be displayed vs the other input view.
    /// So, the view is made visible and the hint label top
    /// constraint is adjusted.
    var textView: UITextView {
        self.hintLabelToTitleLabelConstraint?.isActive = false
        self._textField.isHidden = true
        self.hintLabelToTextFieldConstraint?.isActive = false
        self._textView.isHidden = false
        self.hintLabelToTextViewConstraint?.isActive = true
        return self._textView
    }

    // It might be too prescriptive to change the isEnabled
    // state here, but let's roll with it for now.  Note that
    // steps will need to actively call lookReady() to re-enable
    // the button.
    var secondaryButton: UIButton {
        self._secondaryButton.isHidden = false
        return self._secondaryButton
    }

    // It might be too prescriptive to change the isEnabled
    // state here, but let's roll with it for now.  Note that
    // steps will need to actively call lookReady() to re-enable
    // the button.
    var primaryButton: UIButton {
        self._primaryButton
    }

    lazy var buttonStack: UIStackView = {
        let view = UIStackView()
        view.axis = self.buttonStyle.stackAxis
        view.spacing = self.buttonStyle.spacing
        view.useAutoLayout()
        return view
    }()

    let buttonStyle: ButtonStyle

    // MARK: Lifecycle

    init(buttonStyle: ButtonStyle) {
        self.buttonStyle = buttonStyle
        super.init(frame: .zero)
        self.backgroundColor = .appBackground
        self.constrainSubviews()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Layout

    private func constrainSubviews() {
        let width = CGFloat(256)
        let height = CGFloat(62)

        self.addSubview(self.titleLabel)
        self.titleLabel.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
        let topSpace: CGFloat = UIScreen.main.isShort ? 72 : 94
        titleLabelTopConstraint = self.titleLabel.pinTopToSuperview(constant: topSpace)
        self.titleLabel.constrainWidth(to: width)

        self.addSubview(self._textField)
        self._textField.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
        self._textField.pinTop(toBottomOf: self.titleLabel, constant: 44)
        self._textField.constrainWidth(to: width)
        self._textField.constrainHeight(to: height)

        self.addSubview(self._textView)
        self._textView.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
        textViewTopConstraint = self._textView.pinTop(toBottomOf: self.titleLabel, constant: 44)
        self._textView.constrainWidth(to: 300)

        self.addSubview(self.hintLabel)
        self.hintLabel.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
        self.hintLabel.constrainWidth(to: width)

        // pin hint label to all three components but only activate the title label one
        self.hintLabelToTitleLabelConstraint = self.hintLabel.pinTop(toBottomOf: self.titleLabel, constant: Layout.verticalSpacing, activate: false)
        self.hintLabelToTitleLabelConstraint?.isActive = true
        self.hintLabelToTextFieldConstraint = self.hintLabel.pinTop(toBottomOf: self._textField, constant: Layout.verticalSpacing, activate: false)
        self.hintLabelToTextViewConstraint = self.hintLabel.pinTop(toBottomOf: self._textView, constant: Layout.verticalSpacing, activate: false)

        self.primaryButton.roundedCorners(radius: self.buttonStyle.buttonHeight / 2)

        for button in [self._secondaryButton, self._primaryButton] {
            button.constrainHeight(to: self.buttonStyle.buttonHeight)
            self.buttonStack.addArrangedSubview(button)
        }

        if self.buttonStyle.requiresSpacer {
            self.buttonStack.insertArrangedSubview(UIView(), at: 1)
        }

        self.addSubview(self.buttonStack)
        let sideInset: CGFloat = self.buttonStyle == .verticalStack ? 48 : Layout.horizontalSpacing
        let insets = UIEdgeInsets(top: 0, left: sideInset, bottom: -10, right: -sideInset)
        Layout.fillBottom(of: self, with: self.buttonStack, insets: insets, respectSafeArea: true)
    }

    // MARK: UITextViewDelegate

    func textViewDidChange(_ textView: UITextView) {
        self.textViewValueDidChange?(textView)
    }

    // MARK: UITextFieldDelegate

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        primaryButton.sendActions(for: .touchUpInside)
        return true
    }

    // MARK: Internal actions

    @objc private func _textFieldValueDidChange(textField: UITextField) {
        self.textFieldValueDidChange?(textField)
    }

    @objc private func _secondaryButtonTouchUpInside(button: UIButton) {
        self.secondaryButtonTouchUpInside?(button)
    }

    @objc private func _primaryButtonTouchUpInside(button: UIButton) {
        self.primaryButtonTouchUpInside?(button)
    }

    // MARK: Public action closures

    var textFieldValueDidChange: ((UITextField) -> Void)?
    var textViewValueDidChange: ((UITextView) -> Void)?
    var secondaryButtonTouchUpInside: ((UIButton) -> Void)?
    var primaryButtonTouchUpInside: ((UIButton) -> Void)?

    // MARK: Animations

    func lookBusy(after: TimeInterval = 1, disable button: UIButton? = nil) {
        self.isUserInteractionEnabled = false
        button?.isEnabled = false
        // AppController.shared.showProgress(after: after)
    }

    func lookReady() {
        self.isUserInteractionEnabled = true
        self._secondaryButton.isEnabled = true
        self._primaryButton.isEnabled = true
        AppController.shared.hideProgress()
    }
}
