//
//  Bot+AppConfiguration.swift
//  Planetary
//
//  Created by Christoph on 10/25/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

extension Bot {

    func loginWithCurrentAppConfiguration(completion: @escaping ((Bool) -> Void)) {

        // current configuration is required
        guard let configuration = AppConfiguration.current else {
            completion(false)
            return
        }

        // login with the current configuration
        Bots.current.login(with: configuration) {
            didLogin in
            completion(didLogin)
        }
    }

    /// Attempts to log in with the specified configuration.  If the bot is already logged in
    /// this will return `true`, even if not the same identity.  It is unlikely that the current
    /// configuration will be different than the bot's logged in identity, so hopefully not an issue.
    func login(with configuration: AppConfiguration,
               completion: @escaping ((Bool) -> Void))
    {
        guard configuration.canLaunch else { completion(false); return }
        guard let network = configuration.network else { completion(false); return }
        guard let secret = configuration.secret else { completion(false); return }

        Bots.current.login(network: network,
                           hmacKey: configuration.hmacKey,
                           secret: secret)
        {
            error in
            let loggedIn = ((error as? BotError) == .alreadyLoggedIn) || error == nil
            completion(loggedIn)
        }
    }
}
