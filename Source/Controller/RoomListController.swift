//
//  RoomListController.swift
//  Planetary
//
//  Created by Matthew Lorentz on 8/3/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation
import Logger
import UIKit
import Analytics

/// A controller for the `RoomListView`. Manages CRUD operations for a list of joined room servers.
@MainActor class RoomListController: RoomListViewModel {
    
    @Published var rooms = [Room]()
    
    @Published var loadingMessage: String?
    
    @Published var errorMessage: String?
    
    private var bot: Bot
    
    init(bot: Bot) {
        self.bot = bot
        loadRooms()
    }
    
    // MARK: View Model Actions
    
    func deleteRooms(at indexes: IndexSet) {
        Task {
            do {
                for index in indexes {
                    let room = self.rooms[index]
                    try await self.bot.delete(room: room)
                }
                
                self.rooms.remove(atOffsets: indexes)
            } catch {
                Log.optional(error)
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    func addRoom(from string: String) {
        let sanitizedString = string.trimmed
        // Check if this is an invitation
        if let url = URL(string: sanitizedString), RoomInvitationRedeemer.canRedeem(inviteURL: url) {
            loadingMessage = Localized.joiningRoom.text
            Task {
                try await RoomInvitationRedeemer.redeem(inviteURL: url, in: AppController.shared, bot: Bots.current)
                Analytics.shared.trackDidJoinRoom(at: sanitizedString)
                self.finishAddingRoom()
            }
        // Check if this is an address
        } else if let address = MultiserverAddress(string: sanitizedString) {
            loadingMessage = Localized.joiningRoom.text
            Task {
                do {
                    try await self.bot.insert(room: Room(address: address))
                    Analytics.shared.trackDidJoinRoom(at: address.string)
                    self.finishAddingRoom()
                } catch {
                    Log.optional(error)
                    self.errorMessage = error.localizedDescription
                }
            }
        } else {
            errorMessage = Localized.Error.invalidRoomInvitationOrAddress.text
        }
    }
    
    func didDismissError() {
        errorMessage = nil
    }
    
    func refresh() {
        loadRooms()
    }
    
    func open(_ room: Room) {
        guard let url = URL(string: "https://\(room.address.host)") else {
            errorMessage = Localized.ManageRelays.invalidRoomURL.text
            return
        }
        
        UIApplication.shared.open(url)
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
