//
//  PushAPIService.swift
//  Planetary
//
//  Created by Martin Dutra on 5/18/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation

protocol PushAPIService {
    
    func update(_ token: Data?, for identity: Identity, completion: @escaping ((Bool, APIError?) -> Void))
}
