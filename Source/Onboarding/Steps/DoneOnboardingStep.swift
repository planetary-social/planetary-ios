//
//  DoneOnboardingStep.swift
//  FBTT
//
//  Created by Christoph on 7/16/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

class DoneOnboardingStep: OnboardingStep {

    private let directoryToggle: TitledToggle = {
        let view = TitledToggle.forAutoLayout()
        view.titleLabel.text = Text.Onboarding.listMeTitle.text
        view.subtitleLabel.text = Text.Onboarding.listMeMessage.text
        view.toggle.isOn = true
        return view
    }()

    init() {
        super.init(.done)
    }

    override func customizeView() {

        let insets = UIEdgeInsets(top: 30, left: 0, bottom: -16, right: 0)
        Layout.fillSouth(of: self.view.hintLabel, with: self.directoryToggle, insets: insets)

        self.view.hintLabel.text = Text.Onboarding.thanksForTrying.text

        self.view.primaryButton.setText(.doneOnboarding)
    }

    override func primary() {

        self.data.joinedDirectory = self.directoryToggle.toggle.isOn

        // SIMULATE ONBOARDING
        if self.data.simulated {
            Analytics.trackOnboardingComplete(self.data)
            self.next();
            return
        }

        if self.data.joinedDirectory == false {
            self.next()
            return
        }

        guard let me = self.data.context?.identity else {
            Log.unexpected(.missingValue, "Was expecting self.data.context.person.identity, skipping step")
            self.next()
            return
        }

        self.view.lookBusy(disable: self.view.primaryButton)

        VerseAPI.directory(show: me) {
            [weak self] success, error in
            Log.optional(error)
            guard let me = self else { return }
            me.view.lookReady()
            if success {
                Analytics.trackOnboardingComplete(me.data)
                me.next()
            }
        }
    }

    override func didStart() {
        if self.data.simulated { return }
        guard let identity = self.data.context?.identity else { return }
        Onboarding.set(status: .completed, for: identity)
    }
}
