//
//  PreloadedPubRepository.swift
//  Planetary
//
//  Created by Matthew Lorentz on 3/15/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation

class PreloadedPubService {
    
    private var bot: Bot
    private var bundle: Bundle
    
    init(bot: Bot, bundle: Bundle? = nil) {
        self.bot = bot
        if let bundle = bundle {
            self.bundle = bundle
        } else {
            self.bundle = Bundle(for: type(of: self))
        }
    }
    
    func updatePreloadedPubs() {
        guard let url = bundle.url(forResource: "pubFeed", withExtension: "json") else {
            return
        }
        print("---Preloading pubs")
        
        bot.preloadFeed(at: url) { error in
            print(error?.localizedDescription)
            print("--- Finished")
        }
    }
}
