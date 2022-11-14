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
        // TODO: If viewModel.rooms, is populated skip to done step of Onboarding.
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
    @State var roomIsSelected = false
    var aliasServerParagraph1 = Localized.Onboarding.aliasServerInformationParagraph1.text
    var aliasServerParagraph2 = Localized.Onboarding.aliasServerInformationParagraph2.text
    var changeAliasText = Localized.Onboarding.changeAlias.text
    var titleChooseAliasServer = Localized.Onboarding.StepTitle.joinedRoom.text
    var titleChooseAlias = Localized.Onboarding.StepTitle.alias.text
    
    var step: RoomsOnboardingStep
    
    var body: some View {
        
        VStack(alignment: .leading, spacing: 0) {
            // "Chose a Room" text
            if !roomIsSelected {
                VStack {
                    Text(aliasServerParagraph1)
                        .padding(.bottom, 10)
                        .foregroundColor(.onboardingMainText)
                    Text(aliasServerParagraph2) { string in
                        string.foregroundColor = .onboardingMainText
                        if let range = string.range(of: Localized.Onboarding.yourAliasPlanetary.text) {
                            string[range].foregroundColor = .highlightGradientAverage
                        }
                        if let range = string.range(of: Localized.Onboarding.yourAlias.text) {
                            string[range].font = .body.italic()
                        }
                    }
                }
                .padding(.bottom, 20)
            }
            
            VStack {
                ForEach(viewModel.communityRooms) { room in
                    RoomCard(room: room, showTextInput: roomIsSelected)
                        .onTapGesture {
                            Task {
                                do {
                                    await viewModel.addRoom(from: room.address.string, token: room.token)
                                    if roomIsSelected {
                                        viewModel.communityRooms = Environment.PlanetarySystem.communityAliasServers
                                        step.view.titleLabel.text = Localized.Onboarding.StepTitle.joinedRoom.text
                                        roomIsSelected = false
                                    } else {
                                        viewModel.communityRooms = [room]
                                        step.view.titleLabel.text = Localized.Onboarding.StepTitle.alias.text
                                        roomIsSelected = true
                                    }
                                }
                            }
                        }
                        .onSubmit {
                            // TODO: onSubmit action should be a property of RoomCard.swift
                        }
                        .padding(.bottom, 10)
                }
                if roomIsSelected {
                    Text(aliasServerParagraph1)
                        .foregroundColor(.onboardingMainText)
                        .padding(.bottom, 10)
                        .transition(
                            .move(edge: .bottom)
                            .combined(
                                with: AnyTransition.opacity.animation(
                                    .easeInOut(duration: 0.5)
                                )
                            )
                        )
                }
            }.transition(.move(edge: .top))
        }.padding(40)
    }
}
