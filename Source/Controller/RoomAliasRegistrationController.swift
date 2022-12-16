//
//  RoomAliasRegistrationController.swift
//  Planetary
//
//  Created by Matthew Lorentz on 8/18/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation
import SwiftUI
import Logger
import Secrets

@MainActor class RoomAliasRegistrationController: AddAliasViewModel {
    
    @Published var rooms: [Room] = [] {
        didSet {
            showJoinPlanetaryRoomButton = !rooms.contains(where: { $0.address.string.contains("planetary.name") })
        }
    }
    
    @Published var loadingMessage: String?
    
    @Published var alertMessage: String?
    
    @Published var alertMessageTitle: String?
    
    @Published var shouldDismiss = false
    
    @Published var showJoinPlanetaryRoomButton = false
    
    private var bot: Bot
    
    init(bot: Bot) {
        self.bot = bot
        
        loadingMessage = Localized.loading.text
        Task {
            await refresh()
            self.loadingMessage = nil
        }
    }
    
    private func refresh() async {
        do {
            self.rooms = try await bot.joinedRooms()
        } catch {
            Log.optional(error)
            self.alertMessageTitle = Localized.error.text
            self.alertMessage = error.localizedDescription
        }
    }
    
    func register(_ desiredAlias: String, in room: Room?) {
        // TODO: normalize
        guard let room = room else {
            alertMessageTitle = Localized.error.text
            // TODO
            alertMessage = "please select a room"
            return
        }
        
        loadingMessage = Localized.loading.text
        Task {
            do {
                _ = try await self.bot.register(alias: desiredAlias, in: room)
                self.shouldDismiss = true
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
                let token = Keys.shared.get(key: .planetaryRoomToken)!
                try await RoomInvitationRedeemer.redeem(token: token, at: "planetary.name", bot: bot)
                await refresh()
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
