//
//  AliasOnboardingStep.swift
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

class AliasOnboardingStep: OnboardingStep {
    
    private var rooms: [Room] = []
    private var viewModel: RoomListController
    
    init() {
        
        viewModel = RoomListController(bot: Bots.current)
        
        super.init(.alias, buttonStyle: .verticalStack)
        let uiHostingController = UIHostingController(
            rootView: AliasOnboardingView(viewModel: self.viewModel)
        )
        uiHostingController.view.backgroundColor = .clear
        Layout.fillSouth(of: view.titleLabel, with: uiHostingController.view)
    }
    
    override func customizeView() {
        self.view.secondaryButton.setText(Localized.Onboarding.aliasSkip)
        self.view.titleLabel.textColor = .onboardingTitle
        self.view.primaryButton.setTitle("Done", for: .normal)
    }
    
    override func performSecondaryAction(sender button: UIButton) {
        self.next(.done)
    }
    
    override func performPrimaryAction(sender button: UIButton) {
        // Do the registration here
        self.next(.done)
    }
}

struct AliasOnboardingView: View {
    @ObservedObject var viewModel: RoomListController
    
    var body: some View {
        
        if let chosenRoom = viewModel.rooms.first {
            VStack {
                RoomCard(room: chosenRoom, showTextInput: true)
                Text(Localized.Onboarding.changeAlias.text)
                    .foregroundColor(Color(uiColor: .onboardingMainText))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 40)
            }.padding(40)
        }
    }
}
