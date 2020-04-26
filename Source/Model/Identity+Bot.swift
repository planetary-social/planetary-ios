//
//  Identity+Bot.swift
//  Planetary
//
//  Created by Zef Houssney on 10/4/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

extension Identity {
    var isCurrentUser: Bool {
        return self == Bots.current.identity
    }

    // a safety to help avoid passing in the current user's identity into an API call
    func assertNotMe() {
        if self.isCurrentUser {
            assertionFailure("Did not expect this to be the current user's Identity.")
        }
    }
    
    func isNotMe(identifier: String) -> Bool {
        return self.self != identifier
    }
    
}
