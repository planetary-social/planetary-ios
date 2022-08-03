//
//  RoomListCoordinator.swift
//  Planetary
//
//  Created by Matthew Lorentz on 8/3/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation
import Logger

@MainActor class RoomListCoordinator: RoomListViewModel {
    
    @Published var rooms = [Room]()
    
    @Published var loadingMessage: String?
    
    @Published var errorMessage: String?
    
    private var bot: Bot
    
    init(bot: Bot) {
        self.bot = bot
        loadRooms()
    }
    
    func loadRooms() {
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
    
    func add(room: String) {
        // TODO: detect invite link
        if let address = MultiserverAddress(string: room) {
            loadingMessage = "Joining room..."
            Task {
                do {
                    try await self.bot.insert(room: Room(address: address))
                } catch {
                    Log.optional(error)
                    self.errorMessage = error.localizedDescription
                }
                self.loadingMessage = nil
                self.loadRooms()
            }
        } else {
            errorMessage = "Could not parse multiserver address."
        }
    }
    
    func didDismissError() {
        errorMessage = nil
    }
}
