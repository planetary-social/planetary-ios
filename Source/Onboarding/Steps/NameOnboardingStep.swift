//
//  NameOnboardingStep.swift
//  FBTT
//
//  Created by Christoph on 7/16/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit
import Analytics

class NameOnboardingStep: OnboardingStep {

    init() {
        super.init(.name, buttonStyle: .horizontalStack)
        Analytics.shared.trackNameStep()
    }

    override func customizeView() {
        self.view.textField.text = ""
        self.view.textField.autocapitalizationType = .words
        self.view.textField.autocorrectionType = .no

        self.view.hintLabel.text = Text.Onboarding.useRealName.text
        self.view.primaryButton.isEnabled = false
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
}
