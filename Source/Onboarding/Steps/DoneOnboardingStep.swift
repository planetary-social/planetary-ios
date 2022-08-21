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
        view.titleLabel.text = Text.sendAnalytics.text
        view.subtitleLabel.text = Text.analyticsMessage.text
        view.toggle.isOn = true
        return view
    }()
    
    private let followPlanetaryToggle: TitledToggle = {
        let view = TitledToggle.forAutoLayout()
        view.titleLabel.text = Text.Onboarding.followPlanetaryToggleTitle.text
        view.subtitleLabel.text = Text.Onboarding.followPlanetaryToggleDescription.text
        view.toggle.isOn = true
        return view
    }()
    
    private let publicWebHostingToggle: TitledToggle = {
        let view = TitledToggle.forAutoLayout()
        view.titleLabel.text = Text.WebServices.publicWebHosting.text
        view.subtitleLabel.text = Text.WebServices.footer.text
        view.toggle.isOn = true
        return view
    }()

    private let joinPlanetarySystemToggle: TitledToggle = {
        let view = TitledToggle.forAutoLayout()
        view.titleLabel.text = Text.Onboarding.joinPlanetarySystem.text
        view.subtitleLabel.text = Text.Onboarding.joinPlanetarySystemDescription.text
        view.toggle.isOn = true
        return view
    }()
    
    private let useTestNetworkToggle: TitledToggle = {
        let view = TitledToggle.forAutoLayout()
        view.titleLabel.text = Text.Onboarding.useTestNetwork.text
        view.subtitleLabel.text = Text.Onboarding.useTestNetworkDescription.text
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

        self.view.hintLabel.text = Text.Onboarding.thanksForTrying.text

        self.view.primaryButton.setText(.doneOnboarding)
        self.view.bringSubviewToFront(view.buttonStack)
    }

    override func performPrimaryAction(sender button: UIButton) {
        self.data.joinPlanetarySystem = self.joinPlanetarySystemToggle.toggle.isOn
        self.data.publicWebHosting = self.publicWebHostingToggle.toggle.isOn
        self.data.analytics = self.analyticsToggle.toggle.isOn
        self.data.followPlanetary = self.followPlanetaryToggle.toggle.isOn
        self.data.useTestNetwork = self.followPlanetaryToggle.toggle.isOn
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

        guard let me = data.context?.identity else {
            Log.unexpected(.missingValue, "Was expecting self.data.context.person.identity, skipping step")
            Analytics.shared.trackOnboardingComplete(self.data.analyticsData)
            self.next()
            return
        }
        
        var operations = [Operation]()
        
        let startOperation = BlockOperation { [weak self] in
            DispatchQueue.main.async { [weak self] in
                if let primaryButton = self?.view.primaryButton {
                    self?.view.lookBusy(after: 0, disable: primaryButton)
                } else {
                    self?.view.lookBusy(after: 0)
                }
            }
        }
        
        if data.followPlanetary {
            let followPlanetaryOperation = FollowOperation(identity: Environment.PlanetarySystem.planetaryIdentity)
            followPlanetaryOperation.addDependency(startOperation)
            operations.append(followPlanetaryOperation)
        }
        
        let publicWebHostingOperation = BlockOperation {
            let semaphore = DispatchSemaphore(value: 0)
            let about = About(about: me, publicWebHosting: data.publicWebHosting)
            let queue = OperationQueue.current?.underlyingQueue ?? .global(qos: .background)
            Bots.current.publish(content: about, completionQueue: queue) { (_, error) in
                Log.optional(error)
                CrashReporting.shared.reportIfNeeded(error: error)
                semaphore.signal()
            }
            semaphore.wait()
        }
        publicWebHostingOperation.addDependency(startOperation)
        
        let bundle = Bundle(path: Bundle.main.path(forResource: "Preload", ofType: "bundle")!)!
        let preloadOperation = LoadBundleOperation(bundle: bundle)
        preloadOperation.addDependency(publicWebHostingOperation)
        
        let refreshOperation = RefreshOperation(refreshLoad: .short)
        refreshOperation.addDependency(preloadOperation)
        
        let completionOperation = BlockOperation { [weak self] in
            DispatchQueue.main.async { [weak self] in
                self?.view.lookReady()
                Analytics.shared.trackOnboardingComplete(data.analyticsData)
                Analytics.shared.trackOnboardingEnd()
                self?.next()
            }
        }
        completionOperation.addDependency(refreshOperation)
        
        operations += [
            startOperation,
            publicWebHostingOperation,
            preloadOperation,
            refreshOperation,
            completionOperation
        ]
        AppController.shared.operationQueue.addOperations(operations, waitUntilFinished: false)
    }

    override func didStart() {
        if self.data.simulated { return }
        guard let identity = self.data.context?.identity else { return }
        Onboarding.set(status: .completed, for: identity)
    }
}
