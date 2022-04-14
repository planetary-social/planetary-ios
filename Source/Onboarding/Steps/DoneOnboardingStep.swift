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
    
    private let publicWebHostingToggle: TitledToggle = {
        let view = TitledToggle.forAutoLayout()
        view.titleLabel.text = Text.PublicWebHosting.title.text
        view.subtitleLabel.text = Text.PublicWebHosting.footer.text
        view.toggle.isOn = true
        return view
    }()

    init() {
        super.init(.done)
    }

    override func customizeView() {

        let insets = UIEdgeInsets(top: 30, left: 0, bottom: -16, right: 0)
        
        Layout.fillSouth(of: self.view.hintLabel, with: self.publicWebHostingToggle, insets: insets)

        self.view.hintLabel.text = Text.Onboarding.thanksForTrying.text

        self.view.primaryButton.setText(.doneOnboarding)
    }

    override func performPrimaryAction(sender button: UIButton) {
        self.data.publicWebHosting = self.publicWebHostingToggle.toggle.isOn
        let data = self.data
        
        // SIMULATE ONBOARDING
        if data.simulated {
            Analytics.shared.trackOnboardingComplete(self.data.analyticsData)
            self.next()
            return
        }

        guard let me = data.context?.identity else {
            Log.unexpected(.missingValue, "Was expecting self.data.context.person.identity, skipping step")
            Analytics.shared.trackOnboardingComplete(self.data.analyticsData)
            self.next()
            return
        }
        
        let startOperation = BlockOperation { [weak self] in
            DispatchQueue.main.async { [weak self] in
                if let primaryButton = self?.view.primaryButton {
                    self?.view.lookBusy(disable: primaryButton)
                } else {
                    self?.view.lookBusy()
                }
            }
        }
        
        let followOperation = BlockOperation {
            let identities = Environment.PlanetarySystem.planets
            let semaphore = DispatchSemaphore(value: identities.count - 1)
            for identity in identities {
                Bots.current.follow(identity) {
                    _, _ in
                    semaphore.signal()
                }
            }
            semaphore.wait()
        }
        followOperation.addDependency(startOperation)
        
        let publicWebHostingOperation = BlockOperation {
            guard data.publicWebHosting else {
                return
            }
            let semaphore = DispatchSemaphore(value: 0)
            let about = About(about: me, publicWebHosting: true)
            let queue = OperationQueue.current?.underlyingQueue ?? .global(qos: .background)
            Bots.current.publish(content: about, completionQueue: queue) { (_, error) in
                Log.optional(error)
                CrashReporting.shared.reportIfNeeded(error: error)
                semaphore.signal()
            }
            semaphore.wait()
        }
        publicWebHostingOperation.addDependency(followOperation)
        
        let bundle = Bundle(path: Bundle.main.path(forResource: "Preload", ofType: "bundle")!)!
        let preloadOperation = LoadBundleOperation(bundle: bundle)
        preloadOperation.addDependency(publicWebHostingOperation)
        
        let refreshOperation = RefreshOperation(refreshLoad: .long)
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
        
        let operations = [startOperation,
                          followOperation,
                          publicWebHostingOperation,
                          preloadOperation,
                          refreshOperation,
                          completionOperation]
        AppController.shared.operationQueue.addOperations(operations,
                                                          waitUntilFinished: false)
    }

    override func didStart() {
        if self.data.simulated { return }
        guard let identity = self.data.context?.identity else { return }
        Onboarding.set(status: .completed, for: identity)
    }
}
