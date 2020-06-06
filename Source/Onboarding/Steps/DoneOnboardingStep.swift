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
    
    private static var refreshBackgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid

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
        if DoneOnboardingStep.refreshBackgroundTaskIdentifier != .invalid {
            UIApplication.shared.endBackgroundTask(DoneOnboardingStep.refreshBackgroundTaskIdentifier)
        }
        
        Log.info("Onboarding triggering a medium refresh")
        let refreshOperation = RefreshOperation()
        refreshOperation.refreshLoad = .medium
        
        let taskName = "OnboardingRefresh"
        let taskIdentifier = UIApplication.shared.beginBackgroundTask(withName: taskName) {
            // Expiry handler, iOS will call this shortly before ending the task
            refreshOperation.cancel()
            UIApplication.shared.endBackgroundTask(DoneOnboardingStep.refreshBackgroundTaskIdentifier)
            DoneOnboardingStep.refreshBackgroundTaskIdentifier = .invalid
        }
        DoneOnboardingStep.refreshBackgroundTaskIdentifier = taskIdentifier
        
        refreshOperation.completionBlock = {
            Log.optional(refreshOperation.error)
            CrashReporting.shared.reportIfNeeded(error: refreshOperation.error)
           
            if taskIdentifier != UIBackgroundTaskIdentifier.invalid {
                UIApplication.shared.endBackgroundTask(taskIdentifier)
                DoneOnboardingStep.refreshBackgroundTaskIdentifier = .invalid
            }
           
            DispatchQueue.main.async {
                completionBlock()
            }
        }
        
        if let path = Bundle.main.path(forResource: "Preload", ofType: "bundle"), let bundle = Bundle(path: path) {
            let preloadOperation = LoadBundleOperation(bundle: bundle)
            refreshOperation.addDependency(preloadOperation)
            AppController.shared.operationQueue.addOperations([preloadOperation, refreshOperation],
                                                              waitUntilFinished: false)
        } else {
            AppController.shared.operationQueue.addOperation(refreshOperation)
        }
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
