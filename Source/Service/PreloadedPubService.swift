//
//  PreloadedPubService.swift
//  Planetary
//
//  Created by Matthew Lorentz on 3/15/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation
import Logger
import CrashReporting

/// A service class that helps manage the pubs that are loaded into Planetary even if they aren't in your social graph
/// (aka community pubs).
///
/// **To add a new Pub**
/// 1. Follow the [internal documentation](https://github.com/planetary-social/infrastructure/wiki/Setting-Up-A-New-Pub)
///     we have for setting up a Planetary pub
/// 2. Generate the pub invitation and make sure it is listed on our internal
///     [Pub Invitation Tracking Page](https://github.com/planetary-social/infrastructure/wiki/Pub-Invitation-Tracking)
/// 3. Add the pub's id to the `pubs` array in the
///     [feed serializer](https://github.com/planetary-social/feed_seralizer/) and run it. Commit and push your
///     changes.
/// 4. Copy the generated `preloadedPubs.json` file into this repo. It should be copied to the directory
///     `Resources/Preload.bundle/Pubs/`.
/// 5. Copy the pub's profile image into `Resources/Preload.bundle/Pubs/Blobs`.
/// 6. Add a entry for the profile image to `Resources/Preload.bundle/Pubs/BlobIdentifiers.plist`. The key should be
///     the filename and the value is the blob ID.
/// 7. Add a new variable for the pub in Planetary.release and Plantary.debug. Add the pub invitation as the variable's
///     value and add the variable to the list of `COMMUNITIES` or `PLANETARY_SYSTEM_PUBS` in the same file.
protocol PreloadedPubService {
    
    /// Initializes the service with the `PreloadedBlobsService` that will be used to preload profile images for the
    /// pubs.
    init(blobService: PreloadedBlobsService.Type)
    
    /// Inserts the preloaded pubs into the Bot's database, loading data from a file named `preloadedPubs.json` in the
    /// given bundle.
    func preloadPubs(in bot: Bot, from bundle: Bundle?)
}

class PreloadedPubServiceAdapter: PreloadedPubService {
    
    private var preloadedBlobsService: PreloadedBlobsService.Type
    
    required init(blobService: PreloadedBlobsService.Type = PreloadedBlobsServiceAdapter.self) {
        self.preloadedBlobsService = blobService
    }
    
    func preloadPubs(in bot: Bot, from bundle: Bundle? = nil) {
        var bundle = bundle
        if bundle == nil,
            let preloadBundlePath = Bundle(for: Self.self).path(forResource: "Preload", ofType: "bundle"),
            let preloadBundle = Bundle(path: preloadBundlePath) {
            bundle = preloadBundle
        }
        
        guard let bundle = bundle else {
            Log.error("Bundle is nil.")
            return
        }

        guard let url = bundle.url(forResource: "preloadedPubs", withExtension: "json", subdirectory: "Pubs") else {
            Log.error("Could not find data for preloaded pubs.")
            return
        }
        
        Log.info("Preloading pub data")
        
        /// This is a one time fix for a bug in the bug about messages. This can be deleted after it has probably run
        /// on everyone's device once. #540
        fixOldPubMessages(in: bot)
        
        bot.preloadFeed(at: url) { error in
            CrashReporting.shared.reportIfNeeded(error: error)
            Log.optional(error)
            Log.info("Finished preloading pub data")
        }
        
        // This service should be made an explicit dependency
        preloadedBlobsService.preloadBlobs(into: bot, from: "Pubs", in: bundle, completion: nil)
    }
    
    /// This is a one time fix for a bug in the bug about messages. This can be deleted after it has probably run on
    /// everyone's device once. #540
    func fixOldPubMessages(in bot: Bot) {
        let hasRunKey = "PreloadedPubService.hasFixedOldPubMessages"
        let hasRun = UserDefaults.standard.bool(forKey: hasRunKey)
        guard !hasRun,
            let goBot = bot as? GoBot,
            let appConfig = goBot.config else {
            return
        }
        
        Log.info("Dropping pub about messages")
        
        let pubs = appConfig.communityPubs + appConfig.systemPubs
        pubs.forEach {
            do {
                try goBot.database.deleteAbouts(for: $0.feed)
            } catch {
                Log.optional(error)
            }
        }
        
        UserDefaults.standard.set(true, forKey: hasRunKey)
        UserDefaults.standard.synchronize()
    }
}
