//
//  ResumeOnboardingStep.swift
//  Planetary
//
//  Created by Christoph on 11/15/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit
import Logger
import CrashReporting

class ResumeOnboardingStep: OnboardingStep {

    init() {
        super.init(.resume)
    }

    override func customizeView() {
        self.view.primaryButton.isHidden = true
    }

    override func didStart() {

        self.view.lookBusy(after: 0)

        // SIMULATE ONBOARDING
        if self.data.simulated {
            self.scheduledNext()
            return
        }

        Onboarding.resume {
            [weak self] context, error in
            CrashReporting.shared.reportIfNeeded(error: error)
            if Log.optional(error) { self?.alert(); return }
            self?.data.context = context
            self?.scheduledNext()
        }
    }

    private func scheduledNext() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.view.lookReady()
            self.next()
        }
    }

    private func alert() {

        // this will try Onboarding.start() again, creating a new
        // configuration and such
        let tryAgain = UIAlertAction(title: Localized.tryAgain.text,
                                     style: .default) {
            [weak self] _ in
            self?.didStart()
        }
        
        let reset = UIAlertAction(
            title: Localized.Onboarding.startOver.text,
            style: .destructive
        ) { _ in
            Task(priority: .userInitiated) {
                let configuration = AppConfiguration.current
                do {
                    try await Bots.current.logout()
                } catch {
                    Log.optional(error)
                }
                configuration?.unapply()
                if let configuration = configuration {
                    AppConfigurations.delete(configuration)
                }
                self.view.lookReady()
                await AppController.shared.relaunch()
            }
        }

        AppController.shared.choose(from: [tryAgain, reset],
                                    title: Localized.Onboarding.somethingWentWrong.text,
                                    message: Localized.Onboarding.resumeRetryMessage.text)
    }
}
