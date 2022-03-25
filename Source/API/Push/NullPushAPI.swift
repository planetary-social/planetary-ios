//
//  NullPushAPI.swift
//  Planetary
//
//  Created by Martin Dutra on 5/18/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation

class NullPushAPI: PushAPIService {
    
    var token: Data?
    
    func update(_ token: Data?, for identity: Identity, completion: @escaping ((Bool, APIError?) -> Void)) {
        self.token = token
        completion(true, nil)
    }
}
