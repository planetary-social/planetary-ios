//
//  WelcomeService.swift
//  Planetary
//
//  Created by Matthew Lorentz on 6/29/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation
import Logger
import CrashReporting

/// A service that shows new users welcome and onboarding messages.
protocol WelcomeService {
    func insertNewMessages(in db: ViewDatabase, from bundle: Bundle?)
}

class WelcomeServiceAdapter: WelcomeService {
    
    let welcomeFeedID: FeedIdentifier = "@l/lzpaG3asUP+kSj1KNdEvh+oIzjmsPBk20X5er3YrI=.ed25519"
    
    let welcomePostJSON = """
     {
       "key": "%cmkZjslKxE4e4j4b+bdMF+x46VQpSVbsJA9RTayRoR4=.sha256",
       "value": {
          "author": "@l/lzpaG3asUP+kSj1KNdEvh+oIzjmsPBk20X5er3YrI=.ed25519",
          "previous": null,
          "sequence": 0,
          "timestamp": 1656528265886,
          "hash": "sha256",
          "content": {
            "type": "post",
            "text": "Welcome to Planetary!",
            "mentions": []
          },
          "signature": "4GEg21vqwye0Wbm5dTJCkq89uw5+bcOLOqQKA9ZnmHzadF2Z29Ny2QIHwCDjQXXN1DdfGmfrIirVYEeRFGX0DA==.sig.ed25519"
        },
        "timestamp": 1656528265886,
        "off_chain": true
      }
    """
    
    func insertNewMessages(in db: ViewDatabase, from bundle: Bundle? = nil) {
        Log.info("Preloading welcome messages")
        
        do {
            var messages = [KeyValue]()
            let now = Date.now.millisecondsSince1970
            
            let followWelcomeAccount = KeyValue(
                key: "%1",
                value: Value(
                    author: db.currentUser!,
                    content: Content(from: Contact(contact: welcomeFeedID, following: true)),
                    hash: "nop",
                    previous: "0",
                    sequence: 1,
                    signature: "1",
                    timestamp: now
                ),
                timestamp: now,
                receivedSeq: 0,
                hashedKey: "1",
                offChain: true
            )
            messages.append(followWelcomeAccount)
            
            let welcomePost = KeyValue(
                key: "%2",
                value: Value(
                    author: welcomeFeedID,
                    content: Content(from: Post(text: "Welcome to Planetary!")),
                    hash: "nop",
                    previous: "1",
                    sequence: 2,
                    signature: "2",
                    timestamp: now
                ),
                timestamp: now,
                receivedSeq: 0,
                hashedKey: "2",
                offChain: true
            )
            messages.append(welcomePost)
            
            var lastRxSeq: Int64 = try db.minimumReceivedSeq()
            
            let newMesgs = messages.map { (message: KeyValue) -> KeyValue in
                lastRxSeq -= 1
                
                return KeyValue(
                    key: message.key,
                    value: message.value,
                    timestamp: now,
                    receivedSeq: lastRxSeq,
                    hashedKey: message.key.sha256hash,
                    offChain: true
                )
            }
            
            try db.fillMessages(msgs: newMesgs)
            Log.info("Finished preloading welcome messages")
        } catch {
            print(error) // shows error
            print("Unable to read file")// local message
        }
    }
}
