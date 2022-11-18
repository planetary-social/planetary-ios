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

class RoomsOnboardingStep: OnboardingStep, ObservableObject {
    
    var viewModel: RoomsOnboardingController
    
    init() {
        
        self.viewModel = RoomsOnboardingController(bot: Bots.current)
        super.init(.aliasServer, buttonStyle: .verticalStack)
        self.view.primaryButton.isHidden = true
    }
    
    override func customizeView() {
        
        let uiHostingController = UIHostingController(
            rootView: RoomsOnboardingView(
                viewModel: self.viewModel,
                step: self
            )
        )
        uiHostingController.view.backgroundColor = .clear
        Layout.fillSouth(of: view.titleLabel, with: uiHostingController.view)
        
        self.view.titleLabel.textColor = .onboardingTitle
     
        self.view.primaryButton.setText(Localized.done)
        
        // Customize appearance of "Skip Choosing Alias" text
        let skipChoosingAliasTextAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 15, weight: .medium),
            .foregroundColor: UIColor.menuSelectedItemText,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        let skipChoosingAliasText = NSMutableAttributedString(
            string: Localized.Onboarding.aliasSkip.text,
            attributes: skipChoosingAliasTextAttributes
        )
        
        self.view.secondaryButton.setAttributedTitle(skipChoosingAliasText, for: .normal)
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
