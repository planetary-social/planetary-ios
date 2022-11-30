//
//  DoneOnboardingStep.swift
//  FBTT
//
//  Created by Christoph on 7/16/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit
import Logger
import Analytics
import CrashReporting

class DoneOnboardingStep: OnboardingStep {
    
    private let analyticsToggle: TitledToggle = {
        let view = TitledToggle.forAutoLayout()
        view.titleLabel.text = Localized.sendAnalytics.text
        view.subtitleLabel.text = Localized.analyticsMessage.text
        view.toggle.isOn = true
        return view
    }()
    
    private let followPlanetaryToggle: TitledToggle = {
        let view = TitledToggle.forAutoLayout()
        view.titleLabel.text = Localized.Onboarding.followPlanetaryToggleTitle.text
        view.subtitleLabel.text = Localized.Onboarding.followPlanetaryToggleDescription.text
        view.toggle.isOn = true
        return view
    }()
    
    private let publicWebHostingToggle: TitledToggle = {
        let view = TitledToggle.forAutoLayout()
        view.titleLabel.text = Localized.WebServices.publicWebHosting.text
        view.subtitleLabel.text = Localized.WebServices.footer.text
        view.toggle.isOn = true
        return view
    }()

    private let joinPlanetarySystemToggle: TitledToggle = {
        let view = TitledToggle.forAutoLayout()
        view.titleLabel.text = Localized.Onboarding.joinPlanetarySystem.text
        view.subtitleLabel.text = Localized.Onboarding.joinPlanetarySystemDescription.text
        view.toggle.isOn = true
        return view
    }()
    
    private let useTestNetworkToggle: TitledToggle = {
        let view = TitledToggle.forAutoLayout()
        view.titleLabel.text = Localized.Onboarding.useTestNetwork.text
        view.subtitleLabel.text = Localized.Onboarding.useTestNetworkDescription.text
        #if DEBUG
        view.toggle.isOn = true
        #else
        view.toggle.isOn = false
        #endif
        return view
    }()
    
    init() {
        super.init(.done)
    }

    override func customizeView() {

        let insets = UIEdgeInsets(top: 30, left: 0, bottom: -16, right: 0)
        
        Layout.fillSouth(of: view.hintLabel, with: analyticsToggle, insets: insets)
        Layout.fillSouth(of: analyticsToggle, with: followPlanetaryToggle)
        Layout.fillSouth(of: followPlanetaryToggle, with: publicWebHostingToggle)
        Layout.fillSouth(of: publicWebHostingToggle, with: joinPlanetarySystemToggle)
        #if DEBUG
        Layout.fillSouth(of: joinPlanetarySystemToggle, with: useTestNetworkToggle)
        useTestNetworkToggle.bottomAnchor.constraint(
            lessThanOrEqualTo: view.buttonStack.topAnchor,
            constant: -Layout.verticalSpacing
        ).isActive = true
        #else
        joinPlanetarySystemToggle.bottomAnchor.constraint(
            lessThanOrEqualTo: view.buttonStack.topAnchor,
            constant: -Layout.verticalSpacing
        ).isActive = true
        #endif

        self.view.hintLabel.text = Localized.Onboarding.orUseTheDefaults.text

        self.view.primaryButton.setText(.doneOnboarding)
        self.view.bringSubviewToFront(view.buttonStack)
    }

    override func performPrimaryAction(sender button: UIButton) {
        self.data.joinPlanetarySystem = self.joinPlanetarySystemToggle.toggle.isOn
        self.data.publicWebHosting = self.publicWebHostingToggle.toggle.isOn
        self.data.analytics = self.analyticsToggle.toggle.isOn
        self.data.followPlanetary = self.followPlanetaryToggle.toggle.isOn
        self.data.useTestNetwork = self.useTestNetworkToggle.toggle.isOn
        let data = self.data
        
        // SIMULATE ONBOARDING
        if data.simulated {
            Analytics.shared.trackOnboardingComplete(self.data.analyticsData)
            self.next()
            return
        }
        
        if !data.analytics {
            Analytics.shared.optOut()
        }
        
        guard data.context?.identity != nil else {
            Log.unexpected(.missingValue, "Was expecting self.data.context.person.identity, skipping step")
            Analytics.shared.trackOnboardingComplete(self.data.analyticsData)
            self.next()
            return
        }
        
        self.next()
    }

    override func didStart() {
        if self.data.simulated { return }
        guard data.context?.identity != nil else { return }
    }
}
