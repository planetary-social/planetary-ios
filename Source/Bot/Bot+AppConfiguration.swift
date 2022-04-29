//
//  Bot+AppConfiguration.swift
//  Planetary
//
//  Created by Christoph on 10/25/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

extension Bot {

    /// Attempts to log in with the specified configuration.  If the bot is already logged in
    /// this will return `true`, even if not the same identity.  It is unlikely that the current
    /// configuration will be different than the bot's logged in identity, so hopefully not an issue.
    func login(with configuration: AppConfiguration,
               completion: @escaping ((Bool) -> Void)) {
        guard configuration.canLaunch else { completion(false); return }
        guard configuration.network != nil else { completion(false); return }

        Bots.current.login(config: configuration) { error in
            let loggedIn = ((error as? BotError) == .alreadyLoggedIn) || error == nil
            completion(loggedIn)
        }
    }
}
