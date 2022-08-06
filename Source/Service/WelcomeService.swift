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
    func insertNewMessages(in db: ViewDatabase) throws
}

class WelcomeServiceAdapter: WelcomeService {
    
    let welcomeFeedID: FeedIdentifier = "@l/lzpaG3asUP+kSj1KNdEvh+oIzjmsPBk20X5er3YrI=.ed25519"
    
    var userDefaults: UserDefaults
    
    let welcomeFlagV1 = "hasBeenWelcomedV1"
    
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }
    
    func insertNewMessages(in db: ViewDatabase) throws {
        
        guard let currentUser = db.currentUser else {
            Log.error("database does not have a currentUser")
            return
        }
        
        let hasBeenWelcomedKey = hasBeenWelcomedKey(for: currentUser)
        
        guard !userDefaults.bool(forKey: hasBeenWelcomedKey) else {
            return
        }
        
        guard try isNewOrDormantUser(currentUser, db: db) else {
            return
        }
        
        Log.info("Preloading welcome messages")
        
        var messages = [KeyValue]()
        messages.append(welcomeAccountAboutMessage())
        messages.append(followWelcomeAccountMessages(author: currentUser))
        messages.append(welcomeMessage(for: currentUser))
        try save(messages: messages, to: db)
        userDefaults.set(true, forKey: hasBeenWelcomedKey)
        
        Log.info("Finished preloading welcome messages")
    }
    
    // MARK: - Helpers
    
    private func save(messages: [KeyValue], to db: ViewDatabase) throws {
        let now = Date.now.millisecondsSince1970
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
    }
    
    func hasBeenWelcomedKey(for user: FeedIdentifier) -> String {
        "\(welcomeFlagV1)-\(user)"
    }
    
    private func fakeMessageID(from string: String) -> MessageIdentifier {
        Data(string.sha256hash.utf8).base64EncodedString()
    }
    
    private func isNewOrDormantUser(_ user: FeedIdentifier, db: ViewDatabase) throws -> Bool {
        var isDormantUser = false
        if let mostRecentPost = try db.lastWrittenMessageDate() {
            let withinLastMonth: TimeInterval = 60 * 60 * 24 * 30
            isDormantUser = abs(mostRecentPost.timeIntervalSinceNow) > withinLastMonth
        }
        let numberOfPublishedMessages = try db.numberOfMessages(for: user)
        let isNewUser = numberOfPublishedMessages < 20
        return isDormantUser || isNewUser
    }
    
    // MARK: - Message Data
    
    private func welcomeAccountAboutMessage() -> KeyValue {
        let timestamp: Double = 1_657_210_389_000 // 2022-07-07
        return KeyValue(
            key: "%0mkZjslKxE4e4j4b+bdMF+x46VQpSVbsJA9RTayRoR4=.sha256",
            value: Value(
                author: welcomeFeedID,
                content: Content(
                    from: About(
                        about: welcomeFeedID,
                        name: Text.Onboarding.welcomeBotName.text,
                        description: Text.Onboarding.welcomeBotBio.text,
                        imageLink: "&XD6l9T+dbtFqlZDbqFHf5Nixo8V7lE8VseArbpZbBwU=.sha256",
                        publicWebHosting: false
                    )
                ),
                hash: "nop",
                previous: nil,
                sequence: 0,
                signature: "nop",
                timestamp: timestamp
            ),
            timestamp: timestamp,
            receivedSeq: 0,
            hashedKey: "nop",
            offChain: true
        )
    }
    
    private func followWelcomeAccountMessages(author: FeedIdentifier) -> KeyValue {
        let now = Date.now.millisecondsSince1970 - 1000 // -1 to make sure this shows below the welcome message
        return KeyValue(
            key: fakeMessageID(from: "followWelcomeAccount" + author + welcomeFeedID),
            value: Value(
                author: author,
                content: Content(from: Contact(contact: welcomeFeedID, following: true)),
                hash: "nop",
                previous: nil,
                sequence: -1,
                signature: "nop",
                timestamp: now
            ),
            timestamp: now,
            receivedSeq: 0,
            hashedKey: "nop",
            offChain: true
        )
    }
    
    private func welcomeMessage(for user: FeedIdentifier) -> KeyValue {
        let now = Date.now.millisecondsSince1970
        return KeyValue(
            key: fakeMessageID(from: "welcomeMessage" + user + welcomeFeedID),
            value: Value(
                author: welcomeFeedID,
                content: Content(
                    from: Post(
                        blobs: [
                            Blob(identifier: "&byA+y+gkCxLzF3vK3wW+R/gLtsVip+ctE3xGAMDjTe8=.sha256"),
                            Blob(identifier: "&hH+8apK7YrPInrrefyojVwSB7T4Erp82rjE4SNhbl1k=.sha256"),
                            Blob(identifier: "&hZHFLmckfJGG2+hRhIuNWSdEodSs2G+v1VjNaWE/fn0=.sha256"),
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
    }
}
