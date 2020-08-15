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
    
    func refresh(completionBlock: @escaping () -> Void) {
        
        let availableStars = Set(Environment.Constellation.stars)
        let randomStars = availableStars.randomSample(3)
        let redeemInviteOperations = randomStars.map { RedeemInviteOperation(token: $0.invite) }
        
        let completionOperation = BlockOperation {
            DispatchQueue.main.async {
                completionBlock()
            }
        }
        redeemInviteOperations.forEach { completionOperation.addDependency($0) }
        
        let operations: [Operation]
        if let path = Bundle.main.path(forResource: "Preload", ofType: "bundle"), let bundle = Bundle(path: path) {
            let preloadOperation = LoadBundleOperation(bundle: bundle)
            redeemInviteOperations.forEach { $0.addDependency(preloadOperation) }
            operations = [preloadOperation] + redeemInviteOperations + [completionOperation]
        } else {
            operations = redeemInviteOperations + [completionOperation]
        }
        AppController.shared.operationQueue.addOperations(operations,
                                                          waitUntilFinished: false)
    }

    override func primary() {

        self.data.joinedDirectory = self.directoryToggle.toggle.isOn
        
        let data = self.data

        let skipToNextStep = {
            self.view.lookBusy()
            self.refresh { [weak self] in
                self?.view.lookReady()
                self?.next()
            }
        }
        
        // SIMULATE ONBOARDING
        if data.simulated {
            Analytics.shared.trackOnboardingComplete(self.data)
            skipToNextStep()
            return
        }

        if data.joinedDirectory == false {
            Analytics.shared.trackOnboardingComplete(self.data)
            skipToNextStep()
            return
        }

        guard let me = data.context?.identity else {
            Log.unexpected(.missingValue, "Was expecting self.data.context.person.identity, skipping step")
            Analytics.shared.trackOnboardingComplete(self.data)
            skipToNextStep()
            return
        }

        self.view.lookBusy(disable: self.view.primaryButton)
        DirectoryAPI.shared.directory(show: me) { [weak self] success, error in
            Log.optional(error)
            CrashReporting.shared.reportIfNeeded(error: error)
            if success {
                self?.refresh { [weak self] in
                    self?.view.lookReady()
                    Analytics.shared.trackOnboardingComplete(data)
                    self?.next()
                }
            } else {
                self?.view.lookReady()
            }
        }
    }

    override func didStart() {
        if self.data.simulated { return }
        guard let identity = self.data.context?.identity else { return }
        Onboarding.set(status: .completed, for: identity)
    }
}
