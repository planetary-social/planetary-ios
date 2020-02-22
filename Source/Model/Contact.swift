//
//  Contact.swift
//  FBTTUnitTests
//
//  Created by Christoph on 1/28/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

struct Contact: ContentCodable {

    let type: ContentType
    let contact: Identity
    let following: Bool?
    let blocking: Bool?

    var identity: Identity {
        return self.contact
    }
    
    init(contact: Identity, following: Bool) {
        self.type = .contact
        self.contact = contact
        self.following = following
        self.blocking = false
    }
    
    init(contact: Identity, blocking: Bool) {
        self.type = .contact
        self.contact = contact
        self.following = false
        self.blocking = blocking
    }
}

extension Contact {

    var isFollowing: Bool {
        return self.following ?? false
    }

    var isBlocking: Bool {
        return self.blocking ?? false
    }

    var isValid: Bool {
        return self.following != nil || self.blocking != nil
    }
}
