//
//  PhoneOnboardingStep.swift
//  FBTT
//
//  Created by Christoph on 7/16/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import PhoneNumberKit
import UIKit
import Logger

class PhoneOnboardingStep: OnboardingStep {

    private lazy var phoneNumberField: PhoneNumberTextField = {
        let view = PhoneNumberTextField.forAutoLayout()
        view.addTarget(self, action: #selector(phoneNumberFieldValueDidChange), for: .editingChanged)
        view.delegate = self.view
        view.font = UIFont.systemFont(ofSize: 22, weight: .medium)
        view.layer.borderColor = UIColor.border.text.cgColor
        view.layer.borderWidth = 1
        view.layer.cornerRadius = 10
        view.placeholder = Text.Onboarding.phoneNumber.text
        view.textAlignment = .center
        view.textContentType = .telephoneNumber
        return view
    }()

    init() {
        super.init(.phone, buttonStyle: .horizontalStack)
    }

    override func customizeView() {
        self.view.addSubview(self.phoneNumberField)
        self.phoneNumberField.constrain(to: self.view.textField)
        self.view.textField.isHidden = true
        self.view.hintLabel.text = Text.Onboarding.phoneNumberConfirmationMessage.text
        self.view.primaryButton.isEnabled = false
    }

    override func didStart() {
        self.phoneNumberField.becomeFirstResponder()
    }

    @objc private func phoneNumberFieldValueDidChange() {
        self.view.primaryButton.isEnabled = self.phoneNumberField.isValidNumber
    }

    override func performPrimaryAction(sender: UIButton) {

        guard let string = self.phoneNumberField.text else { return }
        guard let number = string.phoneNumber() else { return }
        self.data.phone = string

        // TODO https://app.asana.com/0/914798787098068/1146899678085089/f
        // TODO find a way to skip phone and verification for TestFlight builds
        // necessary for TestFlight review
        if string == "(415) 555-5785" { self.next(); return }

        // SIMULATE ONBOARDING
        if self.data.simulated { self.next(); return }

        self.view.lookBusy(disable: self.view.primaryButton)

        Onboarding.requestCode(country: "\(number.countryCode)", phone: "\(number.nationalNumber)") {
            [weak self] success, error in
            self?.view.lookReady()
            Log.optional(error)
            CrashReporting.shared.reportIfNeeded(error: error)
            if success { self?.next() }
        }
    }
}
