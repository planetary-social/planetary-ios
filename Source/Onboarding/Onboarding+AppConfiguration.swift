//
//  Onboarding+AppConfiguration.swift
//  Planetary
//
//  Created by Christoph on 11/18/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

extension Onboarding.Context {

    init?(from configuration: AppConfiguration) {

        guard let identity = configuration.identity else { return nil }
        guard let network = configuration.network else { return nil }
        guard let bot = configuration.bot else { return nil }

        self.identity = identity
        self.network = network
        self.signingKey = configuration.hmacKey
        self.bot = bot
        self.about = nil
        self.person = nil
    }

    static func fromCurrentAppConfiguration() -> Onboarding.Context? {
        guard let configuration = AppConfiguration.current else { return nil }
        return Onboarding.Context(from: configuration)
    }
}
