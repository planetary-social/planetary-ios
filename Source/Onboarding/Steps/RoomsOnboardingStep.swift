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

class RoomsOnboardingStep: OnboardingStep, ObservableObject {
    
    var viewModel: RoomListController
 
    init() {
        
        self.viewModel = RoomListController(bot: Bots.current)
        // TODO: if there is an already rooms in viewModel.rooms, skip to done step.
        if !viewModel.rooms.isEmpty {
            super.init(.done)
        } else {
            super.init(.joinedRoom, buttonStyle: .verticalStack)
        }
        self.view.primaryButton.isHidden = true
    }
    
    override func customizeView() {
        
        let uiHostingController = UIHostingController(
            rootView: RoomsOnboardingView(viewModel: self.viewModel, step: self)
        )
        uiHostingController.view.backgroundColor = .clear
        Layout.fillSouth(of: view.titleLabel, with: uiHostingController.view)
        
        self.view.titleLabel.textColor = .onboardingTitle
        self.view.primaryButton.isHidden = true
        
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
    
    override func performSecondaryAction(sender button: UIButton) {
        self.next(.done)
    }
}

struct RoomsOnboardingView: View {
    @ObservedObject var viewModel: RoomListController
    var step: RoomsOnboardingStep
    
    var body: some View {
        
        VStack {
            
            Text(Localized.Onboarding.aliasServerInformationParagraph1.text)
                .padding(.bottom, 10)
                .foregroundColor(.onboardingMainText)
            Text(Localized.Onboarding.aliasServerInformationParagraph2.text) { string in
                string.foregroundColor = .onboardingMainText
                if let range = string.range(of: Localized.Onboarding.yourAliasPlanetary.text) {
                    string[range].foregroundColor = .highlightGradientAverage
                }
                if let range = string.range(of: Localized.Onboarding.yourAlias.text) {
                    string[range].font = .body.italic()
                }
            }.padding(.bottom, 20)
            
            ForEach(viewModel.communityRooms) { room in
                RoomCard(room: room, showTextInput: false)
                    .onTapGesture {
                        Task {
                            do {
                                try await viewModel.addRoom(from: room.address.string, token: room.token)
                                step.next(.alias)
                            } catch {
                                Log.error("Could not add room")
                            }
                        }
                    }
                    .padding(.bottom, 10)
            }
        }.padding(40)
    }
}
