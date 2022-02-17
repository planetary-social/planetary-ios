//
//  PhoneVerifyOnboardingStep.swift
//  FBTT
//
//  Created by Christoph on 7/16/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import PhoneNumberKit
import UIKit
import Logger

class PhoneVerifyOnboardingStep: OnboardingStep {

    private lazy var retryButton: UIButton = {
        let button = UIButton(type: .system)
        button.addTarget(self, action: #selector(retryButtonTouchUpInside), for: .touchUpInside)
        button.setText(.didntGetSMS)
        button.useAutoLayout()
        return button
    }()

    init() {
        super.init(.phoneVerify, buttonStyle: .horizontalStack)
    }

    override func customizeView() {
        self.view.textField.keyboardType = .numberPad
        self.view.textField.textContentType = .oneTimeCode
        Layout.fillSouth(of: self.view.textField, with: self.retryButton)
        self.view.primaryButton.isEnabled = false
    }

    override func didStart() {
        view.textField.becomeFirstResponder()
    }

    @objc private func retryButtonTouchUpInside() {

        let reenter = UIAlertAction(title: Text.Onboarding.reenter.text, style: .default) {
            [unowned self] action in
            self.back()
        }

        let retry = UIAlertAction(title: Text.Onboarding.resendSMS.text, style: .cancel) {
            [unowned self] action in
            self.resend()
        }

        let phone = self.data.phone ?? ""
        let title = Text.Onboarding.youEnteredNumber.text(["phone": phone])

        AppController.shared.choose(from: [reenter, retry],
                                    title: title,
                                    message: Text.Onboarding.confirmNumber.text)
    }

    private func resend() {

        guard let number = self.data.phone?.phoneNumber() else { return }

        self.view.lookBusy()

        Onboarding.requestCode(country: "\(number.countryCode)", phone: "\(number.nationalNumber)") {
            [weak self] success, error in
            self?.view.lookReady()
        }
    }

    override func textFieldValueDidChange(_ textField: UITextField) {
        self.view.primaryButton.isEnabled = textField.text?.isValidVerificationCode ?? false
        self.data.code = textField.text
    }

    override func performPrimaryAction(sender button: UIButton) {

        guard let number = self.data.phone?.phoneNumber() else { return }
        guard let code = self.data.code, code.isValidVerificationCode else { return }

        // TODO https://app.asana.com/0/914798787098068/1146899678085089/f
        // TODO find a way to skip phone and verification for TestFlight builds
        // necessary for TestFlight review
        if code == "767897" { self.next(); return }

        // SIMULATE ONBOARDING
        if self.data.simulated { self.next(); return }

        self.view.lookBusy(disable: self.view.primaryButton)

        Onboarding.verifyCode(code, country: "\(number.countryCode)", phone: "\(number.nationalNumber)") {
            [weak self] success, error in
            self?.view.lookReady()
            Log.optional(error)
            CrashReporting.shared.reportIfNeeded(error: error)
            if success { self?.next() }
            else { self?.view.textField.shake() }
        }
    }
}
