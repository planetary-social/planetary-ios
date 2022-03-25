//
//  PreloadedPubService.swift
//  Planetary
//
//  Created by Matthew Lorentz on 3/15/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation
import Logger

/// A service class that helps manage the pubs that are loaded into Planetary even if they aren't in your social graph
/// (aka community pubs).
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
        
        bot.preloadFeed(at: url) { error in
            Log.optional(error)
            Log.info("Finished preloading pub data")
        }
        
        // This service should be made an explicit dependency
        preloadedBlobsService.preloadBlobs(into: bot, from: "Pubs", in: bundle, completion: nil)
    }
}
