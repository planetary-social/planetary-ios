//
//  NameOnboardingStep.swift
//  FBTT
//
//  Created by Christoph on 7/16/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

class NameOnboardingStep: OnboardingStep {

    init() {
        super.init(.name)
    }

    override func customizeView() {
        self.view.textField.text = ""
        self.view.textField.autocapitalizationType = .words
        self.view.textField.autocorrectionType = .no

        self.view.hintLabel.text = Localized.Onboarding.useRealName.text
        self.view.primaryButton.isEnabled = false
        self.view.secondaryButton.setText(.doItLater)
    }

    override func didStart() {
        self.view.textField.becomeFirstResponder()
    }

    override func textFieldValueDidChange(_ textField: UITextField) {
        self.view.primaryButton.isEnabled = textField.text?.isValidName ?? false
        self.data.name = textField.text
    }

    override func performPrimaryAction(sender button: UIButton) {
        guard let name = self.data.name else { return }
        guard name.isValidName else { return }
        super.performPrimaryAction(sender: button)
    }
    
    override func performSecondaryAction(sender button: UIButton) {
        self.data.name = nil
        // Skip bio + photo steps
        self.next(.done)
    }
}
