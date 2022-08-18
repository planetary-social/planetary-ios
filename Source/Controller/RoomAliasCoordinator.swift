//
//  RoomAliasCoordinator.swift
//  Planetary
//
//  Created by Matthew Lorentz on 8/18/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation

class RoomAliasCoordinator: ManageAliasViewModel {
    
    @Published var aliases: [RoomAlias] = []
    
    @Published var loadingMessage: String?
    
    @Published var errorMessage: String?
    
    var bot: Bot
    
    var registrationViewModel: RoomAliasRegistrationCoordinator {
        RoomAliasRegistrationCoordinator(bot: bot)
    }
    
    internal init(bot: Bot) {
        self.bot = bot
    }
    
    func deleteRooms(at: IndexSet) {
            
    }
    
    func addAlias(from: String) {
        
    }
    
    func open(_ alias: RoomAlias) {
        
    }
    
    func didDismissError() {
        
    }
    
    func refresh() {
        
    }
    
    func deleteAliases(at: IndexSet) {
    }
}

