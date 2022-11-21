//
//  OnboardingRoomController.swift
//  Planetary
//
//  Created by Chad Sarles on 11/16/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation
import Logger

@MainActor class RoomsOnboardingController: RoomsOnboardingViewModel {
    
    @Published var rooms = [Room]()
    
    @Published var errorMessage: String?
    
    @Published var communityAliasServers = Environment.PlanetarySystem.communityAliasServers
    
    @Published var title = Localized.Onboarding.StepTitle.aliasServer.text
    
    @Published var selectedRoom: Room?
    
    @Published var alias = ""
    
    @Published var registeredRoom = false
    
    private var bot: Bot
    
    init(bot: Bot) {
        self.bot = bot
    }
    
    // MARK: View Model Actions
    
    func aliasIsValid() -> Bool {
        guard alias.count > 1,
            !alias.starts(with: "-") else {
            return false
        }
        return true
    }
    
    func joinAndRegister(room: Room, alias: String) async throws -> RoomAlias {
        errorMessage = nil
        do {
            if registeredRoom == false {
                try await addRoom(from: room.address.string, token: room.token)
            }
            return try await register(alias, in: room)
        } catch {
            errorMessage = error.localizedDescription
            Log.error(error.localizedDescription)
            throw error
        }
    }
    
    func addRoom(from string: String, token: String?) async throws {
        if let address = MultiserverAddress(string: string) {
            do {
                if let token {
                    try await RoomInvitationRedeemer.redeem(address: address,
                                                            token: token,
                                                            in: AppController.shared,
                                                            bot: Bots.current,
                                                            showAlert: false)
                    registeredRoom = true
                }
            } catch {
                Log.optional(error)
                self.errorMessage = error.localizedDescription
            }
        } else {
            errorMessage = Localized.Error.invalidRoomInvitationOrAddress.text
        }
    }
    
    func register(_ desiredAlias: String, in room: Room) async throws -> RoomAlias {
        let alias = try await self.bot.register(alias: desiredAlias, in: room)
        return alias
    }
    
    func selectRoom(room: Room) {
        title = Localized.Onboarding.StepTitle.alias.text
        communityAliasServers = [room]
        selectedRoom = room
    }
    
    func deselectRoom() {
        title = Localized.Onboarding.StepTitle.aliasServer.text
        communityAliasServers = Environment.PlanetarySystem.communityAliasServers
        selectedRoom = nil
    }
}

/// An enumeration of the errors produced by `RoomsOnboardingController`.
enum RoomRegistrationError: LocalizedError {
    
    case aliasTaken
    case invalidFormat
    case unknownError
    
    var errorDescription: String? {
        switch self {
        case .aliasTaken:
            return Localized.Onboarding.aliasTaken.text
        case .invalidFormat:
            return Localized.Onboarding.invalidAliasFormat.text
        case .unknownError:
            return Localized.Onboarding.unknownAliasRegistrationError.text
        }
    }
}
