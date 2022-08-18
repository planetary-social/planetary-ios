//
//  RoomAliasRegistrationCoordinator.swift
//  Planetary
//
//  Created by Matthew Lorentz on 8/18/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation
import SwiftUI
import Logger

class RoomAliasRegistrationCoordinator: AddAliasViewModel {
    
    @Published var rooms: [Room] = []
    
    @Published var loadingMessage: String?
    
    @Published var errorMessage: String?
    
    init(bot: Bot) {
        loadingMessage = Text.loading.text
        Task.detached(priority: .userInitiated) {
            do {
                self.rooms = try await bot.joinedRooms()
            } catch {
                Log.optional(error)
                self.errorMessage = error.localizedDescription
            }
            self.loadingMessage = nil
        }
    }
    
    func register(_ desiredAlias: String, in room: Room?) {
        
    }
}
