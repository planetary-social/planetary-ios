//
//  IdentityFixtures.swift
//  Planetary
//
//  Created by Matthew Lorentz on 2/23/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation

struct IdentityFixture {
    static let alice: Identity = "@pEq+oDSFsYZfSow78WQcPzAAKnxCYEMZJlzTUoOAq9U=.ed25519"
    static let bob: Identity = "@ar0OcuproJ8kODB9fn4iYhxQeR1gSJLtJiup2s2nAiI=.ed25519"
    
    /// An identity that FakeBot doesn't have an About message for
    static let noAbout: Identity = "@92830123eoietnaioht29091209eisntniaoe+=.unsupported"
    
    /// An identity with an about in FakeBot but no name
    static let noName: Identity = "@124312414112323t29091209eisntniaoe+=.ed25519"
}
