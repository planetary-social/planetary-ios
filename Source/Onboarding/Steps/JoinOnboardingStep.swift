//
//  JoinOnboardingStep.swift
//  FBTT
//
//  Created by Christoph on 7/18/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit
import Logger
import CrashReporting

@MainActor class JoinOnboardingStep: OnboardingStep {

    init() {
        super.init(.join)
    }

    override func customizeView() {
        self.view.primaryButton.isHidden = true
    }

    override func didStart() {
        self.view.lookBusy(after: 0)

        // SIMULATE ONBOARDING
        if self.data.simulated {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.view.lookReady()
                self.next()
            }
            return
        }

        Task { [weak self] in
            var context: Onboarding.Context?
            
            do {
                context = try await Onboarding.createProfile(from: data)
                self?.view.lookReady()
            } catch {
                Log.optional(error)
                CrashReporting.shared.reportIfNeeded(error: error)
                self?.view.lookReady()
                self?.alert(error: error)
                return
            }
            
            self?.data.context = context
            if data.name != nil {
                // Proceed to bio + photo steps
                self?.next()
            } else {
                // Skip bio + photo
                self?.next(.done)
            }
        }
    }

    private func alert(error: Error?) {

        // this will try Onboarding.start() again, creating a new
        // configuration and such
        let tryAgain = UIAlertAction(title: Text.tryAgain.text,
                                     style: .default) {
            [weak self] _ in
            self?.tryAgain()
        }

        // this will delete the current configuration (if it matches the
        // context's identity) and start at the beginning of onboarding
        let startOver = UIAlertAction(title: Text.Onboarding.startOver.text,
                                      style: .destructive) {
            [weak self] _ in
            self?.startOver()
        }

        AppController.shared.choose(from: [tryAgain, startOver],
                                    title: Text.Onboarding.somethingWentWrong.text,
                                    message: error?.localizedDescription ?? Text.Onboarding.errorRetryMessage.text)
    }

    /// If `Onboarding.createProfile()` fails, this will reset onboarding and try again
    /// with the same user input values
    private func tryAgain() {
        guard self.data.simulated == false else { return }
        self.view.lookBusy()
        Onboarding.reset {
            [weak self] in
            self?.view.lookReady()
            self?.didStart()
        }
    }

    /// If `Onboarding.createProfile()` fails, this will reset onboarding and go back to
    /// the very first onboarding step, and dropping all user input.
    private func startOver() {
        guard self.data.simulated == false else { return }
        self.view.lookBusy()
        Onboarding.reset {
            [weak self] in
            self?.view.lookReady()
            AppController.shared.launch()
        }
    }
}
