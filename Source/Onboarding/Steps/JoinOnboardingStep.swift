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
        guard !data.simulated else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.view.lookReady()
                self.next()
            }
            return
        }

        Task { [weak self] in
            let context: Onboarding.Context?
            
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
            self?.next()
        }
    }

    private func alert(error: Error?) {

        // this will try Onboarding.start() again, creating a new
        // configuration and such
        let tryAgain = UIAlertAction(title: Localized.tryAgain.text,
                                     style: .default) {
            [weak self] _ in
            self?.tryAgain()
        }

        // this will delete the current configuration (if it matches the
        // context's identity) and start at the beginning of onboarding
        let startOver = UIAlertAction(title: Localized.Onboarding.startOver.text,
                                      style: .destructive) {
            [weak self] _ in
            self?.startOver()
        }

        AppController.shared.choose(from: [tryAgain, startOver],
                                    title: Localized.Onboarding.somethingWentWrong.text,
                                    message: error?.localizedDescription ?? Localized.Onboarding.errorRetryMessage.text)
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
        Onboarding.reset { [weak self] in
            DispatchQueue.main.async {
                self?.view.lookReady()
                AppController.shared.launch()
            }
        }
    }
}
