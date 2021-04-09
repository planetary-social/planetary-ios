//
//  JoinOnboardingStep.swift
//  FBTT
//
//  Created by Christoph on 7/18/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

class JoinOnboardingStep: OnboardingStep {

    init() {
        super.init(.join)
    }

    override func customizeView() {
        self.view.primaryButton.isHidden = true
    }

    override func didStart() {

        // TODO if this fails they get stuck
        guard let birthdate = self.data.birthdate else { return }
        //guard let phone = self.data.phone else { return }
        let phone = "800-555-1212"
        guard let name = self.data.name else { return }

        self.view.lookBusy(after: 0)

        // SIMULATE ONBOARDING
        if self.data.simulated {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.view.lookReady()
                self.next();
            }
            return
        }

        Onboarding.start(birthdate: birthdate, phone: phone, name: name) { [weak self] context, error in
            
            Log.optional(error)
            CrashReporting.shared.reportIfNeeded(error: error)
            
            self?.view.lookReady()
            guard let context = context else {
                self?.alert(error: error)
                return
            }
            self?.data.context = context
            
            self?.next()
        }
    }

    private func alert(error: Error?) {

        // this will try Onboarding.start() again, creating a new
        // configuration and such
        let tryAgain = UIAlertAction(title: Text.tryAgain.text,
                                     style: .default)
        {
            [weak self] action in
            self?.tryAgain()
        }

        // this will delete the current configuration (if it matches the
        // context's identity) and start at the beginning of onboarding
        let startOver = UIAlertAction(title: Text.Onboarding.startOver.text,
                                      style: .destructive)
        {
            [weak self] action in
            self?.startOver()
        }

        AppController.shared.choose(from: [tryAgain, startOver],
                                    style: .alert,
                                    title: Text.Onboarding.somethingWentWrong.text,
                                    message: error?.localizedDescription ?? Text.Onboarding.errorRetryMessage.text)
    }

    /// If `Onboarding.start()` fails, this will reset onboarding and try again
    /// with the same user input values
    private func tryAgain() {
        guard self.data.simulated == false else { return }
        self.view.lookBusy()
        Onboarding.reset() {
            [weak self] in
            self?.view.lookReady()
            self?.didStart()
        }
    }

    /// If `Onboarding.start()` fails, this will reset onboarding and go back to
    /// the very first onboarding step, and dropping all user input.
    private func startOver() {
        guard self.data.simulated == false else { return }
        self.view.lookBusy()
        Onboarding.reset() {
            [weak self] in
            self?.view.lookReady()
            AppController.shared.launch()
        }
    }
}
