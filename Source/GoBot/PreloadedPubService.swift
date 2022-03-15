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
    /// Inserts the preloaded pubs into the Bot's database, loading data from a file named `pubFeed.json` in the given
    /// bundle.
    static func preloadPubs(in bot: Bot, from bundle: Bundle?)
}

class PreloadedPubServiceAdapter: PreloadedPubService {
    
    class func preloadPubs(in bot: Bot, from bundle: Bundle? = nil) {
        let bundle: Bundle = bundle ?? Bundle(for: Self.self)
        
        guard let url = bundle.url(forResource: "pubFeed", withExtension: "json") else {
            Log.error("Could not find data for preloaded pubs.")
            return
        }
        
        Log.info("Preloading pub data")
        
        bot.preloadFeed(at: url) { error in
            Log.optional(error)
            Log.info("Finished preloading pub data")
        }
    }
}
