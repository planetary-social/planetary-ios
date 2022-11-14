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
    
    var viewModel: RoomListController
    
    init() {
        
        self.viewModel = RoomListController(bot: Bots.current)
        super.init(.aliasServer, buttonStyle: .verticalStack)
        self.view.primaryButton.isHidden = true
    }
    
    override func customizeView() {
        
        let uiHostingController = UIHostingController(
            rootView: RoomsOnboardingView(
                viewModel: self.viewModel,
                step: self,
                backButtonAction: {
                    print("test")
                })
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
    
    override func willStart() {
        if !viewModel.rooms.isEmpty || viewModel.communityAliasServers.isEmpty {
            Log.unexpected(.incorrectValue, "viewModel is in unexpected state.")
            Analytics.shared.trackOnboardingComplete(self.data.analyticsData)
            self.next()
            return
        }
    }
    
    override func performSecondaryAction(sender button: UIButton) {
        self.next()
    }
}

struct RoomsOnboardingView: View {
    
    @ObservedObject var viewModel: RoomListController
    @State var roomIsSelected = false
    
    let aliasServerInformation = Localized.Onboarding.aliasServerInformation.text
    let changeAliasText = Localized.Onboarding.changeAlias.text
    let titleChooseAliasServer = Localized.Onboarding.StepTitle.aliasServer.text
    let titleChooseAlias = Localized.Onboarding.StepTitle.alias.text
    let step: RoomsOnboardingStep
    let backButtonAction: () -> Void
    
    var body: some View {
        
        VStack {
            // "Chose a Room" text
            if !roomIsSelected {
                VStack {
                    Text(aliasServerInformation) { string in
                        string.foregroundColor = .onboardingMainText
                        if let range = string.range(of: Localized.Onboarding.yourAliasPlanetary.text) {
                            string[range].foregroundColor = .highlightGradientAverage
                        }
                        if let range = string.range(of: Localized.Onboarding.yourAlias.text) {
                            string[range].font = .body.italic()
                        }
                    }
                }
                .padding(.bottom, 25)
            }
            
            VStack {
                ForEach(viewModel.communityAliasServers) { room in
                    RoomCard(
                        room: room,
                        showTextInput: roomIsSelected,
                        backAction: {
                            roomIsSelected = false
                            viewModel.communityAliasServers = Environment.PlanetarySystem.communityAliasServers
                        }, onSubmitAction: { alias in
                            Task {
                                do {
                                    await viewModel.addRoom(from: room.address.string, token: room.token)
                                    try await viewModel.register(alias, in: room)
                                    step.self.next()
                                } catch {
                                    // errorMessage = error.localizedDescription
                                    Log.error(error.localizedDescription)
                                }
                            }
                        }
                    )
                    .onTapGesture {
                        if !roomIsSelected {
                            viewModel.communityAliasServers = [room]
                            step.view.titleLabel.text = Localized.Onboarding.StepTitle.alias.text
                            roomIsSelected = true
                        }
                    }
//                    .padding(.bottom, 5)
                }
                if roomIsSelected {
                    Text(titleChooseAlias)
                        .foregroundColor(.onboardingMainText)
                        .padding(.top, 20)
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
