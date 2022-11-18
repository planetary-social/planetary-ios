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
    
    @Published var loadingMessage: String?
    
    @Published var errorMessage: String?
    
    @Published var communityAliasServers = Environment.PlanetarySystem.communityAliasServers
    
    private var joinedRoom = false
    private var addedAlias = false
    
    private var bot: Bot
    
    init(bot: Bot) {
        self.bot = bot
    }
    
    // MARK: View Model Actions
    
    func joinAndRegister(room: Room, alias: String) async throws {
        errorMessage = nil
        do {
            if joinedRoom == false {
                let myTask = Task {
                    try await addRoom(from: room.address.string, token: room.token)
                }
                _ = await myTask.result
            }
            if addedAlias == false {
                try await register(alias, in: room)
            }
        } catch {
            errorMessage = error.localizedDescription
            Log.error(error.localizedDescription)
        }
    }
        
    func addRoom(from string: String, token: String?) async throws {
        // Check if this is an invitation
        if let url = URL(string: string), RoomInvitationRedeemer.canRedeem(inviteURL: url) {
            loadingMessage = Localized.joiningRoom.text
                do {
                    try await RoomInvitationRedeemer.redeem(inviteURL: url, in: AppController.shared, bot: Bots.current)
                    joinedRoom = true
                } catch {
                    Log.optional(error)
                    self.errorMessage = error.localizedDescription
                }
                
                self.finishAddingRoom()
        // Check if this is an address
        } else if let address = MultiserverAddress(string: string) {
            loadingMessage = Localized.joiningRoom.text
                do {
                    if let token {
                        await RoomInvitationRedeemer.redeem(address: address, token: token, in: AppController.shared, bot: Bots.current)
                        joinedRoom = true
                        self.finishAddingRoom()
                    } else {
                        try await self.bot.insert(room: Room(address: address))
                        self.finishAddingRoom()
                    }
                } catch {
                    Log.optional(error)
                    self.errorMessage = error.localizedDescription
                }
        } else {
            errorMessage = Localized.Error.invalidRoomInvitationOrAddress.text
        }
    }
    
    func register(_ desiredAlias: String, in room: Room) async throws {

        loadingMessage = Localized.loading.text

        do {
            _ = try await self.bot.register(alias: desiredAlias, in: room)
            addedAlias = true
        } catch {
            Log.optional(error)
            self.errorMessage = error.localizedDescription
        }
        self.loadingMessage = nil
    }
    
    // MARK: Helpers
    
    /// Called at the end of all flows that add a room to the db.
    private func finishAddingRoom() {
        self.loadingMessage = nil
        self.loadRooms()
        AppController.shared.missionControlCenter.sendMission()
    }
    
    /// Loads rooms from the db into this controller's `rooms` array.
    private func loadRooms() {
        loadingMessage = "Loading rooms..."
        Task {
            do {
                let rooms = try await self.bot.joinedRooms()
                self.rooms = rooms
            } catch {
                Log.optional(error)
                self.errorMessage = error.localizedDescription
            }
            self.loadingMessage = nil
        }
    }
}

enum RoomRegistrationError: Error {

    case aliasTaken
    case other(Error?)

    static func optional(_ error: Error?) -> RoomRegistrationError? {
        guard let error = error else { return nil }
        return RoomRegistrationError.other(error)
    }
}
