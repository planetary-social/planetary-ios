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
    
    /// A loading message that should be displayed when it is not nil
    var loadingMessage: String? { get set }
    
    /// An error message that should be displayed when it is not nil
    var errorMessage: String? { get }
    
    /// Tries to add a room to the database from an invitation link or multiserver address string.
    func addRoom(from: String, token: String?) async throws
}

struct RoomsOnboardingView: View {
    
    @ObservedObject var viewModel: RoomsOnboardingController
    
    let aliasServerInformation = Localized.Onboarding.aliasServerInformation.text
    let step: RoomsOnboardingStep
    
    var body: some View {
        
        VStack {
            HStack {
                if viewModel.selectedRoom != nil {
                    Button {
                        withAnimation {
                            viewModel.deselectRoom()
                        }
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                    }
                    .padding(.leading, 10)
                }
                Spacer()
            }
            VStack {
                Text(viewModel.title)
                    .font(Font(UIFont.systemFont(ofSize: 24, weight: .bold)))
                    .foregroundColor(.onboardingTitle)
                    .padding(.bottom, 20)
                
                Spacer(minLength: 20)
                
                // "Chose a Room" text
                if viewModel.selectedRoom == nil {
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
                    .padding(.bottom, 10)
                }
                
                VStack(spacing: 0) {
                    ForEach(viewModel.communityAliasServers) { room in
                        RoomCard(room: room, viewModel: viewModel)
                            .onTapGesture {
                                withAnimation {
                                    viewModel.selectRoom(room: room)
                                }
                            }
                    }
                    
                    if viewModel.selectedRoom != nil {
                        Text(Localized.Onboarding.changeAlias.text)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.onboardingMainText)
                            .padding(.top, 30)
                    }
                    
                    Spacer()
                }
            }.padding(40)
            
            Spacer()
            
            VStack(spacing: 20) {
                
                Button {
                    step.next()
                } label: {
                    Text(viewModel.selectedRoom == nil ? Localized.Onboarding.aliasServerSkip.text :
                            Localized.Onboarding.aliasSkip.text).underline()
                        .foregroundColor(.menuSelectedItemText)
                        .font(Font(UIFont.systemFont(ofSize: 15, weight: .medium)))
                }
                if let room = viewModel.selectedRoom {
                    Button {
                        Task {
                            _ = try await viewModel.joinAndRegister(room: room, alias: viewModel.alias)
                            self.step.next()
                            if let identity = step.data.context?.identity {
                                Onboarding.set(status: .completed, for: identity)
                            }
                        }
                    } label: {
                        Text(Localized.done.text)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PillButtonStyle())
                    .disabled(!viewModel.aliasIsValid())
                    .font(Font(UIFont.verse.pillButton))
                    .frame(maxWidth: .infinity)
                    .padding([.leading, .trailing], 40)
                }
            }.padding(.bottom, 10)
        }.overlay(LoadingOverlay(message: $viewModel.loadingMessage))
    }
}
