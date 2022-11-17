//
//  OnboardingRoomView.swift
//  Planetary
//
//  Created by Chad Sarles on 11/16/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI
import Logger

/// A view model for the RoomListView
@MainActor protocol RoomsOnboardingViewModel: ObservableObject {
    
    /// A list of rooms the user is a member of.
    var rooms: [Room] { get }
    
    /// An error message that should be displayed when it is not nil
    var errorMessage: String? { get }
    
    /// Tries to add a room to the database from an invitation link or multiserver address string.
    func addRoom(from: String, token: String?) async throws
}

struct RoomsOnboardingView: View {
    
    @ObservedObject var viewModel: RoomsOnboardingController
    @State var roomIsSelected = false
    
    let aliasServerInformation = Localized.Onboarding.aliasServerInformation.text
    let changeAliasText = Localized.Onboarding.changeAlias.text
    let titleChooseAliasServer = Localized.Onboarding.StepTitle.aliasServer.text
    let titleChooseAlias = Localized.Onboarding.StepTitle.alias.text
    let step: RoomsOnboardingStep
    
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
                        errorMessage: viewModel.errorMessage,
                        backButtonAction: {
                            roomIsSelected = false
                            viewModel.communityAliasServers = Environment.PlanetarySystem.communityAliasServers
                        }, onSubmitAction: { alias in
                            Task {
                                do {
                                    try await viewModel.joinAndRegister(room: room, alias: alias)
                                } catch {
                                    viewModel.errorMessage = error.localizedDescription
                                }
//                                self.step.next()
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
                }
                if roomIsSelected {
                    Text(changeAliasText)
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
        Spacer()
    }
}
