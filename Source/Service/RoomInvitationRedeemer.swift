//
//  RoomInvitationRedeemer.swift
//  Planetary
//
//  Created by Matthew Lorentz on 8/3/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation
import Logger

/// A container for functions to redeem room server invitations.
enum RoomInvitationRedeemer {
    
    enum RoomInvitationError: Error, LocalizedError {
        
        case invalidURL
        case invitationRedemptionFailedWithReason(String)
        case invitationRedemptionFailed
        case notLoggedIn
        case alreadyJoinedRoom
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return Localized.Error.invalidRoomURL.text
            case .invitationRedemptionFailedWithReason(let reason):
                return Localized.Error.invitationRedemptionFailedWithReason.text(["reason": reason])
            case .invitationRedemptionFailed:
                return Localized.Error.invitationRedemptionFailed.text
            case .notLoggedIn:
                return Localized.Error.notLoggedIn.text
            case .alreadyJoinedRoom:
                return Localized.Error.alreadyJoinedRoom.text
            }
        }
    }
    
    /// A model for the request body of an HTTP request to claim a room invitation.
    fileprivate struct ClaimInvitationRequest: Codable {
        var id: String
        var invite: String
    }
    
    /// A model for the JSON response to an HTTP request to claim a room invitation.
    fileprivate struct ClaimInvitationResponse: Codable {
        var status: String
        var multiserverAddress: String?
        var error: String?
    }
    
    /// A model for the JSON response to an HTTP request to open a room invitation link programatically.
    fileprivate struct OpenInvitationResponse: Codable {
        var status: String
        var invite: String?
        var postTo: String?
        var error: String?
    }
    
    /// Returns true if the URL looks like a valid invite URL. An invite URL is the URL generated by the room
    /// to be shared with the invitee, not the link that is triggered by the "Join Room" button on the room
    /// server website.
    static func canRedeem(inviteURL url: URL) -> Bool {
        guard url.scheme == "https",
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            components.path == "/join",
            let queryParams = components.queryItems,
            let tokenParam = queryParams.first(where: { $0.name == "token" }),
            tokenParam.value?.isEmpty == false else {
            
            return false
        }
        
        return true
    }
    
    /// Returns true if the URL looks like a valid redirect URL. The redirect URL is the URL triggered by tapping the
    /// "Join Room" button on the room server website or by programatically claiming an invite URL.
    static func canRedeem(redirectURL url: URL) -> Bool {
        guard url.scheme == URL.ssbScheme,
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            components.path == "experimental",
            let queryParams = components.queryItems,
            let actionParam = queryParams.first(where: { $0.name == "action" }),
            actionParam.value == "claim-http-invite",
            queryParams.first(where: { $0.name == "invite" })?.value != nil,
            let postToParam = queryParams.first(where: { $0.name == "postTo" })?.value,
            URL(string: postToParam) != nil else {
            
            return false
        }
        
        return true
    }
    
    // Redeems token with a given `MultiserverAddress`
    static func redeem(address: MultiserverAddress, token: String, in controller: AppController, bot: Bot) async {
        do {
            try await RoomInvitationRedeemer.redeem(token: token, at: address.host, bot: bot)
        } catch {
            Log.optional(error)
            await controller.topViewController.alert(error: error)
        }
    }
    
    /// Joins a room server, adding it to the database so that we can use it for syncing in the future. An invite URL
    /// is the URL generated by the room to be shared with the invitee, not the link that is triggered by the
    /// "Join Room" button on the room server website.
    static func redeem(inviteURL url: URL, in controller: AppController, bot: Bot, showToast: Bool = true) async {
        guard url.scheme == "https",
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            components.path == "/join",
            let queryParams = components.queryItems,
            let tokenParam = queryParams.first(where: { $0.name == "token" }),
            tokenParam.value?.isEmpty == false else {
            
            Log.error("invalid room URL: \(url.absoluteURL)")
            await controller.topViewController.alert(error: RoomInvitationError.invalidURL)
            return
        }
        
        guard let jsonURL = URL(string: url.absoluteString + "&encoding=json") else {
            Log.error("could not build URL from: \(url.absoluteURL)")
            await controller.topViewController.alert(error: RoomInvitationError.invalidURL)
            return
        }
        
        do {
            var request = URLRequest(url: jsonURL)
            request.httpMethod = "GET"
            let (responseData, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(OpenInvitationResponse.self, from: responseData)
            
            if let token = response.invite, let postTo = response.postTo, let postToURL = URL(string: postTo) {
                await post(token, to: postToURL, controller: controller, bot: bot, showToast: true)
            } else {
                Log.error("Got failure response from room: \(String(describing: responseData.string))")
                if let errorMessage = response.error {
                    await controller.topViewController.alert(
                        error: RoomInvitationError.invitationRedemptionFailedWithReason(errorMessage)
                    )
                } else {
                    await controller.topViewController.alert(error: RoomInvitationError.invitationRedemptionFailed)
                }
            }
        } catch {
            Log.optional(error)
            await controller.topViewController.alert(
                error: RoomInvitationError.invitationRedemptionFailedWithReason(error.localizedDescription)
            )
        }
    }
    
    /// Joins a room server, adding it to the database so that we can use it for syncing in the future. The redirect
    /// URL is the URL triggered by tapping the "Join Room" button on the room server website or by programatically
    /// claiming an invite URL.
    static func redeem(redirectURL url: URL, in controller: AppController, bot: Bot, showToast: Bool = true) async {
        guard url.scheme == URL.ssbScheme,
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            components.path == "experimental",
            let queryParams = components.queryItems,
            let actionParam = queryParams.first(where: { $0.name == "action" }),
            actionParam.value == "claim-http-invite",
            let inviteCode = queryParams.first(where: { $0.name == "invite" })?.value,
            let postToParam = queryParams.first(where: { $0.name == "postTo" })?.value,
            let postToURL = URL(string: postToParam) else {
            
            Log.error("invalid room URL: \(url.absoluteURL)")
            await controller.topViewController.alert(error: RoomInvitationError.invalidURL)
            return
        }
        
        await post(inviteCode, to: postToURL, controller: controller, bot: bot, showToast: showToast)
    }
    
    static func redeem(token: String, at host: String, bot: Bot) async throws {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.queryItems = [URLQueryItem(name: "token", value: token)]
        components.path = "/invite/consume"
        guard let url = components.url else {
            throw RoomInvitationError.invalidURL
        }
        try await post(token, to: url, bot: bot)
    }
    
    /// Posts the invite token to the given URL, storing the room data in the given `bot` and displaying the result
    /// of the operation in the `controller`.
    private static func post(_ token: String, to url: URL, controller: AppController, bot: Bot, showToast: Bool) async {
        do {
            try await post(token, to: url, bot: bot)
            if showToast {
                await controller.showToast(Localized.invitationRedeemed.text)
            }
        } catch {
            Log.optional(error)
            await controller.topViewController.alert(error: error)
        }
    }
    
    /// Posts the invite token to the given URL, storing the room data in the given `bot` and displaying the result
    /// of the operation in the `controller`.
    private static func post(_ token: String, to url: URL, bot: Bot) async throws {

        // If app isn't running, the bot must log in before redeeming room invite.
        if bot.identity == nil, let appConfiguration = AppConfiguration.current {
            do {
                try await bot.login(config: appConfiguration)
            } catch {
                Log.error("Bot is unable to log in to redeem invitation.")
                throw RoomInvitationError.notLoggedIn
            }
        }

        guard let identity = bot.identity else {
            Log.error("missing identity for room invitation redemption: \(url.absoluteURL)")
            throw RoomInvitationError.notLoggedIn
        }
        
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            let claimInvitationRequest = ClaimInvitationRequest(id: identity, invite: token)
            request.httpBody = try JSONEncoder().encode(claimInvitationRequest)
            let (responseData, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(ClaimInvitationResponse.self, from: responseData)
            
            if response.status == "successful",
                let addressString = response.multiserverAddress,
                let address = MultiserverAddress(string: addressString) {
                
                let room = Room(address: address)
                do {
                    try await bot.insert(room: room)
                } catch {
                    throw RoomInvitationError.alreadyJoinedRoom
                }
                return
            } else {
                Log.error("Got failure response from room: \(String(describing: responseData.string))")
                if let errorMessage = response.error {
                    throw RoomInvitationError.invitationRedemptionFailedWithReason(errorMessage)
                } else {
                    throw RoomInvitationError.invitationRedemptionFailed
                }
            }
        } catch {
            throw RoomInvitationError.invitationRedemptionFailedWithReason(error.localizedDescription)
        }
    }
}
