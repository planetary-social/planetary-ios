//
//  RoomsOnboardingStep.swift
//  Planetary
//
//  Created by Chad Sarles on 11/1/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit
import Logger
import CrashReporting
import SwiftUI
import Secrets
import Analytics

/// Presents a choice of alias servers to join and allows a user to register an alias.
class RoomsOnboardingStep: OnboardingStep, ObservableObject {
    
    var viewModel: RoomsOnboardingController
    
    init() {
        
        self.viewModel = RoomsOnboardingController(bot: Bots.current)
        super.init(.aliasServer, buttonStyle: .verticalStack)
        self.view.primaryButton.isHidden = true
        self.view.titleLabel.removeFromSuperview()
        self.view.buttonStack.removeFromSuperview()
        self.view.hintLabel.removeFromSuperview()
    }
    
    override func customizeView() {
        
        let uiHostingController = UIHostingController(
            rootView: RoomsOnboardingView(
                viewModel: self.viewModel,
                step: self
            )
        )
        uiHostingController.view.backgroundColor = .clear
        
        Layout.fill(view: view, with: uiHostingController.view)
    }
    
    override func willStart() {
        if !viewModel.rooms.isEmpty || viewModel.communityAliasServers.isEmpty {
            Log.unexpected(.incorrectValue, "viewModel is in unexpected state.")
            if let identity = self.data.context?.identity {
                Onboarding.set(status: .completed, for: identity)
            }
            Analytics.shared.trackOnboardingComplete(self.data.analyticsData)
            self.next()
            return
        }
    }
    
    override func performSecondaryAction(sender button: UIButton) {
        self.next()
    }
}
