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
    
    func insertNewMessages(in db: ViewDatabase, from bundle: Bundle? = nil) {
        Log.info("Preloading welcome messages")
        
        do {
            var messages = [KeyValue]()
            let now = Date.now.millisecondsSince1970
            
            let welcomeAccountAbout = KeyValue(
                key: "%0mkZjslKxE4e4j4b+bdMF+x46VQpSVbsJA9RTayRoR4=.sha256",
                value: Value(
                    author: welcomeFeedID,
                    content: Content(from:
                        About(
                            about: welcomeFeedID,
                            name: Text.Onboarding.welcomeBotName.text,
                            description: nil,
                            imageLink: "&XD6l9T+dbtFqlZDbqFHf5Nixo8V7lE8VseArbpZbBwU=.sha256",
                            publicWebHosting: false
                        )
                    ),
                    hash: "nop",
                    previous: nil,
                    sequence: 0,
                    signature: "nop",
                    timestamp: now
                ),
                timestamp: now,
                receivedSeq: 0,
                hashedKey: "nop",
                offChain: true
            )
            messages.append(welcomeAccountAbout)

            
            let followWelcomeAccount = KeyValue(
                key: "%1mkZjslKxE4e4j4b+bdMF+x46VQpSVbsJA9RTayRoR4=.sha256",
                value: Value(
                    author: db.currentUser!,
                    content: Content(from: Contact(contact: welcomeFeedID, following: true)),
                    hash: "nop",
                    previous: nil,
                    sequence: 1,
                    signature: "nop",
                    timestamp: now
                ),
                timestamp: now,
                receivedSeq: 0,
                hashedKey: "nop",
                offChain: true
            )
            messages.append(followWelcomeAccount)
            
            let welcomePost = KeyValue(
                key: "%2mkZjslKxE4e4j4b+bdMF+x46VQpSVbsJA9RTayRoR4=.sha256",
                value: Value(
                    author: welcomeFeedID,
                    content: Content(
                        from: Post(
                            blobs: [
                                Blob(identifier: "&byA+y+gkCxLzF3vK3wW+R/gLtsVip+ctE3xGAMDjTe8=.sha256"),
                                Blob(identifier: "&hH+8apK7YrPInrrefyojVwSB7T4Erp82rjE4SNhbl1k=.sha256"),
                                Blob(identifier: "&QtZae55Hrc+wC9i0y7AbjCWexR6IL/xCGybgeZ3U088=.sha256"),
                                Blob(identifier: "&nmqgPl0O9J/UzKd1iPERLtwomWho8Q0l5/z6kA7iBZE=.sha256"),
                                Blob(identifier: "&u/3vkSrP5I6Exj3TD1/Ngg4ldhV+YbpzoI4iNIjKKz8=.sha256")
                            ],
                            branches: nil,
                            hashtags: nil,
                            mentions: nil,
                            root: nil,
                            text: Text.Onboarding.welcomeMessage.text
                        )
                    ),
                    hash: "nop",
                    previous: nil,
                    sequence: 2,
                    signature: "nop",
                    timestamp: now
                ),
                timestamp: now,
                receivedSeq: 0,
                hashedKey: "nop",
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
            Log.error("Failed to load welcome messages: \(error.localizedDescription)")
        }
    }
}
