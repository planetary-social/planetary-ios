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
import Secrets

/// A controller for the `RoomListView`. Manages CRUD operations for a list of joined room servers.
@MainActor class RoomListController: RoomListViewModel {
    
    @Published var rooms = [Room]() {
        didSet {
            showJoinPlanetaryRoomButton = !rooms.contains(where: { $0.address.string.contains("planetary.name") })
        }
    }
    
    @Published var loadingMessage: String?
    
    @Published var alertMessage: String?
    
    @Published var alertMessageTitle: String?
    
    @Published var showJoinPlanetaryRoomButton = false
    
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
                self.alertMessageTitle = Localized.error.text
                self.alertMessage = error.localizedDescription
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
                self.finishAddingRoom()
            }
        // Check if this is an address
        } else if let address = MultiserverAddress(string: sanitizedString) {
            loadingMessage = Localized.joiningRoom.text
            Task {
                do {
                    try await self.bot.insert(room: Room(address: address))
                    self.finishAddingRoom()
                } catch {
                    Log.optional(error)
                    self.alertMessageTitle = Localized.error.text
                    self.alertMessage = error.localizedDescription
                }
            }
        } else {
            alertMessageTitle = Localized.error.text
            alertMessage = Localized.Error.invalidRoomInvitationOrAddress.text
        }
    }
    
    func didDismissError() {
        alertMessageTitle = nil
        alertMessage = nil
    }
    
    func refresh() {
        loadRooms()
    }
    
    func open(_ room: Room) {
        guard let url = URL(string: "https://\(room.address.host)") else {
            alertMessageTitle = Localized.error.text
            alertMessage = Localized.ManageRelays.invalidRoomURL.text
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
                self.alertMessageTitle = Localized.error.text
                self.alertMessage = error.localizedDescription
            }
            self.loadingMessage = nil
        }
    }
    
    func joinPlanetaryRoom() {
        loadingMessage = Localized.loading.text
        Task {
            do {
                let host = "planetary.name"
                let token = Keys.shared.get(key: .planetaryRoomToken)!
                try await RoomInvitationRedeemer.redeem(token: token, at: host, bot: bot)
                refresh()
                self.alertMessageTitle = Localized.success.text
                self.alertMessage = Localized.invitationRedeemed.text
            } catch {
                Log.optional(error)
                self.alertMessageTitle = Localized.error.text
                self.alertMessage = error.localizedDescription
            }
            self.loadingMessage = nil
        }
    }
}
