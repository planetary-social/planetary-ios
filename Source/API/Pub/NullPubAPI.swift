//
//  NullPubAPI.swift
//  Planetary
//
//  Created by Martin Dutra on 5/18/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation

class NullPubAPI: PubAPIService {

    func pubsAreOnline(completion: @escaping ((Bool, APIError?) -> Void)) {
        completion(true, nil)
    }
    
    func invitePubsToFollow(_ identity: Identity, completion: @escaping ((Bool, APIError?) -> Void)) {
        completion(true, nil)
    }
}
