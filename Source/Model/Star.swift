//
//  Star.swift
//  Planetary
//
//  Created by Martin Dutra on 8/11/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation

struct Star {
    var feed: Identifier
    var invite: String
    
    init(invite: String) {
        self.invite = invite
        
        // Parse Feed Identity out of the invite
        let range = NSRange(location: 0, length: invite.utf16.count)
        let regex = try! NSRegularExpression(pattern: ".*:[0-9]*:(.*)~.*")
        let match = regex.firstMatch(in: invite, options: [], range: range)!
        let identityRange = Range(match.range(at: 1), in: invite)!
        self.feed = String(invite[identityRange])
    }
}

extension Star: Hashable {
    
    func hash(into hasher: inout Hasher) {
        self.feed.hash(into: &hasher)
    }
    
}
