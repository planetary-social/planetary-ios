//
//  BioOnboardingStep.swift
//  FBTT
//
//  Created by Christoph on 7/16/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit
import Logger
import CrashReporting

class BioOnboardingStep: OnboardingStep, UITextViewDelegate {

    init() {
        super.init(.bio, buttonStyle: .horizontalStack)
    }

    override func customizeView() {
        self.view.textView.becomeFirstResponder()
        self.view.textView.delegate = self
        self.view.textView.backgroundColor = .appBackground
        self.view.hintLabel.text = Text.Onboarding.bioHint.text
        self.view.secondaryButton.setText(.skip)
        self.view.titleLabelTopConstraint?.constant = UIScreen.main.isShort ? Layout.verticalSpacing : Layout.verticalSpacing * 2
        if UIScreen.main.isShort {
            self.view.textViewTopConstraint?.constant = Layout.verticalSpacing
        }
        self.view.hintLabel.pinBottom(toTopOf: self.view.buttonStack, constant: -Layout.verticalSpacing)
    }

    // Limit the number of characters in the bio.
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        textView.text.count + (text.count - range.length) <= 140
    }

    func textViewDidChange(_ textView: UITextView) {
        self.data.bio = textView.text
    }

    override func performSecondaryAction(sender button: UIButton) {
        self.next()
    }
}
