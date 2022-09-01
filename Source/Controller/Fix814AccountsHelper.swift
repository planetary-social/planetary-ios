//
//  Fix814AccountsHelper.swift
//  Planetary
//
//  Created by Matthew Lorentz on 9/1/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation
import Analytics
import Logger

enum Fix814AccountsHelper {

    /// This contains a fix for https://github.com/planetary-social/planetary-ios/issues/814, where all new profiles
    /// (who opted to follow the Planetary account during onboarding) were erroneously being created on the Planetary
    /// Test Network and not the main SSB network.
    ///
    /// This function will detect these accounts, prompt for consent from the user, and then copy their posts
    /// to a new feed on the main network.
    static func fix814Account(
        _ configuration: AppConfiguration,
        appController: AppController,
        userDefaults: UserDefaults
    ) async throws -> AppConfiguration? {
        guard let bot = configuration.bot as? GoBot else {
            return nil
        }
        
        let hasPromptedKey = "hasPromptedFor814Fix-\(configuration.id)"
        let hasPromptedAlready = userDefaults.bool(forKey: hasPromptedKey)
        
        try await bot.login(config: configuration)
        
        // Check if account was created on the test network between the given dates.
        guard !hasPromptedAlready,
            configuration.network == Environment.Networks.test.key,
            let identityCreationDate = try? bot.database.currentUserCreatedDate(),
            identityCreationDate > Date(timeIntervalSince1970: 1_661_265_000), // 2022-08-23 10:30am
            identityCreationDate < Date(timeIntervalSince1970: 1_662_587_210), // 2022-09-07
            let publishedMessages = try? bot.database.publishedMessagesForCurrentUser() else {
            try await bot.logout()
            return nil
        }
        
        Log.info("Running 814 fix. Found \(publishedMessages.count) published messages")
        
        try await bot.logout()
        
        // Confirm with the user
        defer {
            userDefaults.set(true, forKey: hasPromptedKey)
            userDefaults.synchronize()
        }
        let confirmed = await appController.confirm(
            message: Text.confirmCopyToMainNetwork.text
        )
        if !confirmed {
            let areYouSure = await appController.confirm(
                message: Text.confirmSkipCopyToMainNetwork.text
            )
            if areYouSure {
                Log.info("User opted out of 814 fix")
                Analytics.shared.trackDidSkip814Fix()
                return nil
            }
        }
        
        Log.info("User opted into 814 fix")
        Analytics.shared.trackDidStart814Fix()
        
        do {
            // create new configuration on the main network
            let newConfiguration = AppConfiguration(with: configuration.secret)
            newConfiguration.name = configuration.name + "-814fixed"
            newConfiguration.joinedPlanetarySystem = configuration.joinedPlanetarySystem
            newConfiguration.bot = bot
            newConfiguration.ssbNetwork = Environment.Networks.mainNet
            
            try await bot.login(config: newConfiguration)
            
            // copy published messages
            for message in publishedMessages {
                if let codableMessage = message.value.content.codableContent {
                    _ = try await bot.publish(content: codableMessage)
                }
            }
            
            Log.info("Finished copying messages. Applying configuration.")
            
            newConfiguration.apply()
            
            Log.info("814 fix complete.")
            Analytics.shared.trackDidComplete814Fix()
            return newConfiguration
        } catch {
            Log.info("814 fix failed.")
            Log.optional(error)
            Analytics.shared.trackDidFail814Fix(error: error)
            throw error
        }
    }
}
