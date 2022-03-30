//
//  TokenStore.swift
//  Planetary
//
//  Created by H on 19.06.20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation

typealias ReadyCallback = (String) -> Void

// simple store to hold bearer tokens
// TODO: should persist those for their durration
class TokenStore {

    static let shared = TokenStore()

    private var currentBearerToken: String = ""

    func update(_ token: String, expires: Date) {
        print("received new bearer token until: \(expires)") // TODO: analytics event. should track we know where these are going (tack created - consumed)
        self.currentBearerToken = token
        
        // notify waiting callbacks
        // TODO: mutex
        for cb in self.waiting {
            cb(token)
        }
        self.waiting = []
    }

    func current() -> String? {
        // allow blank tokenss
        // guard self.currentBearerToken != "" else { return nil }
        return self.currentBearerToken
    }
    
    // TODO: mutex
    private var waiting: [ReadyCallback] = []
    
    // register handlers that will be notified (with the new token) once a new token is available
    func register(cb: @escaping ReadyCallback) {
        // TODO: mutex
        self.waiting.append(cb)
    }
}
