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
        
        guard !hasPromptedAlready else {
            return nil
        }
        
        let db = ViewDatabase()
        try db.open(path: try configuration.databaseDirectory(), user: configuration.identity)
        
        // Check if account was created on the test network between the given dates.
        guard configuration.network == Environment.Networks.test.key,
            let identityCreationDate = try? db.currentUserCreatedDate(),
            identityCreationDate > Date(timeIntervalSince1970: 1_661_265_000), // 2022-08-23 10:30am
            identityCreationDate < Date(timeIntervalSince1970: 1_662_587_210) else { // 2022-09-07
            await db.close()
            userDefaults.set(true, forKey: hasPromptedKey)
            userDefaults.synchronize()
            return nil
        }
        
        do {
            // Confirm with the user
            let confirmed = await appController.confirm(
                message: Localized.confirmCopyToMainNetwork.text
            )
            if !confirmed {
                let secondConfirm = await appController.confirm(
                    message: Localized.confirmSkipCopyToMainNetwork.text,
                    cancelTitle: Localized.yes.text,
                    confirmTitle: Localized.no.text
                )
                if !secondConfirm {
                    Log.info("User opted out of 814 fix")
                    Analytics.shared.trackDidSkip814Fix()
                    userDefaults.set(true, forKey: hasPromptedKey)
                    userDefaults.synchronize()
                    return nil
                }
            }
            
            Log.info("User opted into 814 fix")
            Analytics.shared.trackDidStart814Fix()
                     
            let publishedMessages = try db.publishedMessagesForCurrentUser()
            await db.close()
            Log.info("Prompting for 814 fix.")
            Log.info("Found \(publishedMessages.count) published messages")
            
            // create new configuration on the main network
            let newConfiguration = AppConfiguration(with: configuration.secret)
            newConfiguration.name = configuration.name + "-814fixed"
            newConfiguration.joinedPlanetarySystem = configuration.joinedPlanetarySystem
            newConfiguration.bot = bot
            newConfiguration.ssbNetwork = Environment.Networks.mainNet
            
            try await bot.login(config: newConfiguration)
            
            // copy published messages
            for message in publishedMessages {
                if let codableMessage = message.content.codableContent {
                    _ = try await bot.publish(content: codableMessage)
                }
            }
            
            Log.info("Finished copying \(newConfiguration.numberOfPublishedMessages) messages. Applying configuration.")
            
            newConfiguration.apply()
            
            userDefaults.set(true, forKey: hasPromptedKey)
            userDefaults.synchronize()
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
