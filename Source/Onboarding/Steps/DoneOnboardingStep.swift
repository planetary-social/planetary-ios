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
        Layout.fillSouth(of: self.view.hintLabel, with: self.directoryToggle, insets: insets)
        
        Layout.fillSouth(of: self.directoryToggle, with: self.publicWebHostingToggle, insets: insets)

        self.view.hintLabel.text = Text.Onboarding.thanksForTrying.text

        self.view.primaryButton.setText(.doneOnboarding)
    }
    

    override func primary() {
        self.data.publicWebHosting = self.publicWebHostingToggle.toggle.isOn
        self.data.joinedDirectory = self.directoryToggle.toggle.isOn
        let data = self.data
        
        // SIMULATE ONBOARDING
        if data.simulated {
            Analytics.shared.trackOnboardingComplete(self.data)
            self.next()
            return
        }

        guard let me = data.context?.identity else {
            Log.unexpected(.missingValue, "Was expecting self.data.context.person.identity, skipping step")
            Analytics.shared.trackOnboardingComplete(self.data)
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
        
        let joinDirectoryOperation = BlockOperation {
            guard data.joinedDirectory else {
                return
            }
            let semaphore = DispatchSemaphore(value: 0)
            DirectoryAPI.shared.directory(show: me) { (success, error) in
                Log.optional(error)
                CrashReporting.shared.reportIfNeeded(error: error)
                semaphore.signal()
            }
            semaphore.wait()
        }
        joinDirectoryOperation.addDependency(startOperation)
        
        let publicWebHostingOperation = BlockOperation {
            guard data.publicWebHosting else {
                return
            }
            let semaphore = DispatchSemaphore(value: 0)
            let about = About(about: me, publicWebHosting: true)
            let queue = OperationQueue.current?.underlyingQueue ?? .global(qos: .background)
            Bots.current.publish(queue: queue, content: about) { (msg, error) in
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
        
        let sendMissionOperation = SendMissionOperation(quality: .high)
        sendMissionOperation.addDependency(preloadOperation)
        
        let refreshOperation = RefreshOperation(refreshLoad: .medium)
        refreshOperation.addDependency(sendMissionOperation)
        
        let completionOperation = BlockOperation { [weak self] in
            DispatchQueue.main.async { [weak self] in
                self?.view.lookReady()
                Analytics.shared.trackOnboardingComplete(data)
                self?.next()
            }
        }
        completionOperation.addDependency(refreshOperation)
        
        let operations = [startOperation,
                          joinDirectoryOperation,
                          publicWebHostingOperation,
                          preloadOperation,
                          sendMissionOperation,
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
