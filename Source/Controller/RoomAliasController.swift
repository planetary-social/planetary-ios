//
//  RoomAliasController.swift
//  Planetary
//
//  Created by Matthew Lorentz on 8/18/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation
import Logger
import UIKit

@MainActor class RoomAliasController: ManageAliasViewModel {
    
    @Published var aliases: [RoomAlias] = []
    
    @Published var loadingMessage: String?
    
    @Published var errorMessage: String?
    
    var bot: Bot
    
    var registrationViewModel: RoomAliasRegistrationController {
        RoomAliasRegistrationController(bot: bot)
    }
    
    internal init(bot: Bot) {
        self.bot = bot
    }
    
    func deleteRooms(at: IndexSet) {
        errorMessage = "not implemented"
    }
    
    func open(_ alias: RoomAlias) {
        UIApplication.shared.open(alias.aliasURL)
    }
    
    func didDismissError() {
        errorMessage = nil
    }
    
    func refresh() {
        loadingMessage = Localized.loading.text
        Task {
            do {
                self.aliases = try await bot.registeredAliases(nil)
            } catch {
                Log.optional(error)
                self.errorMessage = error.localizedDescription
            }
            self.loadingMessage = nil
        }
    }
    
    func deleteAliases(at: IndexSet) {
    }
}
