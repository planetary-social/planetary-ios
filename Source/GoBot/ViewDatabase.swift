//
//  ViewDatabase.swift
//  FBTT
//
//  rough idea: feed createLogStream into specific tables and expose helper functions to query feeds/friends/replies
//
//  Created by Henry Bubert on 30.01.19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import SQLite

import CryptoKit

// schema migration handling
extension Connection {
    public var userVersion: Int32 {
        get { return Int32(try! scalar("PRAGMA user_version;") as! Int64)}
        set { try! run("PRAGMA user_version = \(newValue);") }
    }
}

enum ViewDatabaseTableNames: String {
    case addresses
    case authors
    case messagekeys
    case messages
    case abouts
    case channels
    case channelsAssigned = "channel_assignments"
    case contacts
    case blockedContent = "blocked_content"
    case posts
    case postBlobs = "post_blobs"
    case privates
    case privateRecps = "private_recps"
    case votes
    case tangles
    case branches
    case mentionsMsg = "mention_message"
    case mentionsFeed = "mention_feed"
    case mentionsImage = "mention_image"
    case reports
    case pubs
}

class ViewDatabase {
    var currentPath: String { get { return self.dbPath }}
    private var dbPath: String = "/tmp/unset"
    private var openDB: Connection?

    // TODO: use this to trigger fill on update and wipe previous versions
    // https://app.asana.com/0/914798787098068/1151842364054322/f
    static var schemaVersion: UInt = 20

    // should be changed on login/logout
    private var currentUserID: Int64 = -1

    // skip messages older than this (6 month)
    // this should be removed once the database was refactored
    private var temporaryMessageExpireDate: Double = -60*60*24*30*6

    // MARK: Tables and fields
    private let colID = Expression<Int64>("id")
    
    private let authors: Table
    private let colAuthor = Expression<Identity>("author")
    
    private var msgKeys: Table
    private let colKey = Expression<MessageIdentifier>("key")
    private let colHashedKey = Expression<String>("hashed")
    
    private var msgs: Table
    private let colHidden = Expression<Bool>("hidden")
    private let colRXseq = Expression<Int64>("rx_seq")
    private let colMessageID = Expression<Int64>("msg_id")
    private let colAuthorID = Expression<Int64>("author_id")
    private let colSequence = Expression<Int>("sequence")
    private let colMsgType = Expression<String>("type")
    private let colReceivedAt = Expression<Double>("received_at")
    private let colClaimedAt = Expression<Double>("claimed_at")
    private let colDecrypted = Expression<Bool>("is_decrypted")
    
    private let colMessageRef = Expression<Int64>("msg_ref")

    private var abouts: Table
    private let colAboutID = Expression<Int64>("about_id")
    private let colName = Expression<String?>("name")
    private let colImage = Expression<BlobIdentifier?>("image")
    private let colDescr = Expression<String?>("description")
    private let colPublicWebHosting = Expression<Bool?>("publicWebHosting")
    
    private var currentBlockedContent: Table
    // colID
    private var colIDType = Expression<Int>("type")
    
    private var contacts: Table
    // colAuthorID
    private let colContactID = Expression<Int64>("contact_id")
    private let colContactState = Expression<Int>("state")
    
    private var posts: Table
    private let colText = Expression<String>("text")
    private let colIsRoot = Expression<Bool>("is_root")
    
    private var post_blobs: Table
    // msg_ref
    private let colIdentifier = Expression<String>("identifier") // TODO: blobHash:ID
    // colName
    private let colMetaBytes = Expression<Int?>("meta_bytes")
    private let colMetaWidth = Expression<Int?>("meta_widht")
    private let colMetaHeight = Expression<Int?>("meta_height")
    private let colMetaMimeType = Expression<String?>("meta_mime_type")
    private let colMetaAverageColorRGB = Expression<Int?>("meta_average_color_rgb")

    private var mentions_feed: Table
    // msg_ref
    private let colFeedID = Expression<Int64>("feed_id")
    
    private var mentions_msg: Table
    // msg_ref
    // link_id
    
    private var mentions_image: Table
    // msg_ref
    // link_id
    
    private var votes: Table
    private let colLinkID = Expression<Int64>("link_id")
    private let colValue = Expression<Int>("value")
    private let colExpression = Expression<String>("expression")

    private var channels: Table
    // id
    // name
    private let colLegacy = Expression<Bool>("legacy")
    
    private var channelAssigned: Table // what messages are in a channel?
    // msg_ref
    private let colChanRef = Expression<Int64>("chan_ref")

    private var tangles: Table
    private let colRoot = Expression<Int64>("root")
    
    private var branches: Table
    private let colTangleID = Expression<Int64>("tangle_id")
    private let colBranch = Expression<Int64>("branch")
    
    private var privateRecps: Table
    // msg_ref
    // contact_id
    
    private let addresses: Table
    private let colAddressID = Expression<Int64>("address_id")
    // colAboutID
    private let colAddress = Expression<String>("address")
    private let colWorkedLast = Expression<Date?>("worked_last")
    private let colLastErr = Expression<String>("last_err")
    private let colUse = Expression<Bool>("use")
    private let colRedeemed = Expression<Double?>("redeemed")
    
    // Reports
    private var reports: Table
    // colMessageRef
    // colAuthorID
    private let colReportType = Expression<String>("type")
    private let colCreatedAt = Expression<Double>("created_at")
    
    // Pubs
    private var pubs: Table
    // colMessageRef
    private let colHost = Expression<String>("host")
    private let colPort = Expression<Int>("port")
    // colKey

    init() {
        self.addresses = Table(ViewDatabaseTableNames.addresses.rawValue)
        self.authors = Table(ViewDatabaseTableNames.authors.rawValue)
        self.msgKeys = Table(ViewDatabaseTableNames.messagekeys.rawValue)
        self.msgs = Table(ViewDatabaseTableNames.messages.rawValue)
        self.abouts = Table(ViewDatabaseTableNames.abouts.rawValue)
        self.channels = Table(ViewDatabaseTableNames.channels.rawValue)
        self.channelAssigned = Table(ViewDatabaseTableNames.channelsAssigned.rawValue)
        self.contacts = Table(ViewDatabaseTableNames.contacts.rawValue)
        self.currentBlockedContent = Table(ViewDatabaseTableNames.blockedContent.rawValue)
        self.privateRecps = Table(ViewDatabaseTableNames.privateRecps.rawValue)
        self.posts = Table(ViewDatabaseTableNames.posts.rawValue)
        self.post_blobs = Table(ViewDatabaseTableNames.postBlobs.rawValue)
        self.mentions_msg = Table(ViewDatabaseTableNames.mentionsMsg.rawValue)
        self.mentions_feed = Table(ViewDatabaseTableNames.mentionsFeed.rawValue)
        self.mentions_image = Table(ViewDatabaseTableNames.mentionsImage.rawValue)
        self.votes = Table(ViewDatabaseTableNames.votes.rawValue)
        self.tangles = Table(ViewDatabaseTableNames.tangles.rawValue)
        self.branches = Table(ViewDatabaseTableNames.branches.rawValue)
        self.reports = Table(ViewDatabaseTableNames.reports.rawValue)
        self.pubs = Table(ViewDatabaseTableNames.pubs.rawValue)
    }

    // MARK: open / close / stats

    // IMPORTANT!
    // To force a schema rebuild, like when a new column has been added to
    // models, simply increment the number in the `dbPath`.  For example,
    // changing from "schema-built12.sqlite" to "schema-built13.sqlite"
    // will force a rebuild on next launch.

    func open(path: String, user: Identity) throws {
        if self.isOpen() {
            throw ViewDatabaseError.alreadyOpen
        }
        try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
        self.dbPath = "\(path)/schema-built\(ViewDatabase.schemaVersion).sqlite"
        let db = try Connection(self.dbPath) // Q: use proper fs.join API instead of string interpolation?
        
        db.busyTimeout = 1
        db.busyHandler { (tries) -> Bool in
            return tries < 4
        }
        
        self.openDB = db
        try db.execute("PRAGMA journal_mode = WAL;")
        
        
        // db.trace { print("\tSQL: \($0)") } // print all the statements
        
        try db.transaction {
            if db.userVersion == 0 {
                let schemaV1url = Bundle.current.url(forResource: "ViewDatabaseSchema.sql", withExtension: nil)!
                try db.execute(String(contentsOf: schemaV1url))
                db.userVersion = 8
            } else if db.userVersion == 1 {
                try db.execute("""
                CREATE INDEX messagekeys_key ON messagekeys(key);
                CREATE INDEX messagekeys_id ON messagekeys(id);
                CREATE INDEX posts_msgrefs on posts (msg_ref);
                CREATE INDEX messages_rxseq on messages (rx_seq);
                CREATE INDEX tangle_id on tangles (id);
                CREATE INDEX contacts_state ON contacts (contact_id, state);
                CREATE INDEX contacts_state_with_author ON contacts (author_id, contact_id, state);
                -- add new column to posts and migrate existing data
                ALTER TABLE posts ADD is_root boolean default false;
                CREATE INDEX IF NOT EXISTS posts_roots on posts (is_root);
                UPDATE posts set is_root=true;
                UPDATE posts set is_root=false where msg_ref in (select msg_ref from tangles);
                ALTER TABLE messagekeys ADD hashed text;
                CREATE INDEX messagekeys_hashed ON messagekeys(hashed);
                ALTER TABLE authors ADD hashed text;
                CREATE INDEX authors_hashed ON authors(hashed);
                CREATE TABLE blocked_content ( id integer not null, type integer not null );
                ALTER TABLE abouts ADD publicWebHosting boolean;
                CREATE TABLE reports (
                msg_ref integer not null,
                author_id integer not null,
                type text NOT NULL,
                created_at real NOT NULL,
                FOREIGN KEY ( msg_ref ) REFERENCES messages( "msg_id" ),
                FOREIGN KEY ( author_id ) REFERENCES authors( "id" ));
                ALTER TABLE addresses ADD redeemed real default null;
                CREATE TABLE pubs (
                msg_ref integer not null,
                host text not null,
                port integer not null,
                key text not null,
                FOREIGN KEY ( msg_ref ) REFERENCES messages( "msg_id" ));
                """);
                try self.migrateHashAllMessageKeys()
                db.userVersion = 8
            } else if db.userVersion == 2 {
                try db.execute("""
                -- add new column to posts and migrate existing data
                ALTER TABLE posts ADD is_root boolean default false;
                CREATE INDEX IF NOT EXISTS posts_roots on posts (is_root);
                UPDATE posts set is_root=true;
                UPDATE posts set is_root=false where msg_ref in (select msg_ref from tangles);
                ALTER TABLE messagekeys ADD hashed text;
                CREATE INDEX messagekeys_hashed ON messagekeys(hashed);
                ALTER TABLE authors ADD hashed text;
                CREATE INDEX authors_hashed ON authors(hashed);
                CREATE TABLE blocked_content ( id integer not null, type integer not null );
                ALTER TABLE abouts ADD publicWebHosting boolean;
                CREATE TABLE reports (
                msg_ref integer not null,
                author_id integer not null,
                type text NOT NULL,
                created_at real NOT NULL,
                FOREIGN KEY ( msg_ref ) REFERENCES messages( "msg_id" ),
                FOREIGN KEY ( author_id ) REFERENCES authors( "id" ));
                ALTER TABLE addresses ADD redeemed real default null;
                CREATE TABLE pubs (
                msg_ref integer not null,
                host text not null,
                port integer not null,
                key text not null,
                FOREIGN KEY ( msg_ref ) REFERENCES messages( "msg_id" ));
                """);
                try self.migrateHashAllMessageKeys()
                db.userVersion = 8
            } else if db.userVersion == 3 {
                try db.execute("""
                ALTER TABLE messagekeys ADD hashed text;
                CREATE INDEX messagekeys_hashed ON messagekeys(hashed);
                ALTER TABLE authors ADD hashed text;
                CREATE INDEX authors_hashed ON authors(hashed);
                CREATE TABLE blocked_content ( id integer not null, type integer not null );
                ALTER TABLE abouts ADD publicWebHosting boolean;
                CREATE TABLE reports (
                msg_ref integer not null,
                author_id integer not null,
                type text NOT NULL,
                created_at real NOT NULL,
                FOREIGN KEY ( msg_ref ) REFERENCES messages( "msg_id" ),
                FOREIGN KEY ( author_id ) REFERENCES authors( "id" ));
                ALTER TABLE addresses ADD redeemed real default null;
                CREATE TABLE pubs (
                msg_ref integer not null,
                host text not null,
                port integer not null,
                key text not null,
                FOREIGN KEY ( msg_ref ) REFERENCES messages( "msg_id" ));
                """)
                try self.migrateHashAllMessageKeys()
                db.userVersion = 8
            } else if db.userVersion == 4 {
                try db.execute("""
                ALTER TABLE abouts ADD publicWebHosting boolean;
                CREATE TABLE reports (
                msg_ref integer not null,
                author_id integer not null,
                type text NOT NULL,
                created_at real NOT NULL,
                FOREIGN KEY ( msg_ref ) REFERENCES messages( "msg_id" ),
                FOREIGN KEY ( author_id ) REFERENCES authors( "id" ));
                ALTER TABLE addresses ADD redeemed real default null;
                CREATE TABLE pubs (
                msg_ref integer not null,
                host text not null,
                port integer not null,
                key text not null,
                FOREIGN KEY ( msg_ref ) REFERENCES messages( "msg_id" ));
                """)
                db.userVersion = 8
            } else if db.userVersion == 5 {
                try db.execute("""
                CREATE TABLE reports (
                msg_ref integer not null,
                author_id integer not null,
                type text NOT NULL,
                created_at real NOT NULL,
                FOREIGN KEY ( msg_ref ) REFERENCES messages( "msg_id" ),
                FOREIGN KEY ( author_id ) REFERENCES authors( "id" ));
                ALTER TABLE addresses ADD redeemed real default null;
                CREATE TABLE pubs (
                msg_ref integer not null,
                host text not null,
                port integer not null,
                key text not null,
                FOREIGN KEY ( msg_ref ) REFERENCES messages( "msg_id" ));
                """)
                db.userVersion = 8
            } else if db.userVersion == 6 {
                try db.execute("""
                ALTER TABLE addresses ADD redeemed real default null;
                CREATE TABLE pubs (
                msg_ref integer not null,
                host text not null,
                port integer not null,
                key text not null,
                FOREIGN KEY ( msg_ref ) REFERENCES messages( "msg_id" ));
                """)
                db.userVersion = 8
            } else if db.userVersion == 7 {
                try db.execute("""
                CREATE TABLE pubs (
                msg_ref integer not null,
                host text not null,
                port integer not null,
                key text not null,
                FOREIGN KEY ( msg_ref ) REFERENCES messages( "msg_id" ));
                """)
                db.userVersion = 8
            }
        }

        self.currentUserID = try self.authorID(of: user, make: true)
    }
    
    private func migrateHashAllMessageKeys() throws {
        guard let db = self.openDB else { throw ViewDatabaseError.notOpen }
        for row in try db.prepare(self.msgKeys) {
            try db.run(self.msgKeys.filter(colID == row[colID]).update(colHashedKey <- row[colKey].sha256hash))
        }
    }
    
    // this open() is only needed for testing to extend the max age for the fixures... :'(
    #if DEBUG
    func open(path: String, user: Identity, maxAge: Double) throws {
        try self.open(path: path, user: user)
        self.temporaryMessageExpireDate = maxAge
    }
    #endif

    
    func isOpen() -> Bool {
        return self.openDB != nil
    }
    
    func close() {
        self.openDB = nil
        self.currentUserID = -1
    }
    
    func getOpenDB() -> Connection? {
        guard let db = self.openDB else { return nil }
        return db
    }
    
    // returns the number of rows for the respective tables
    func stats() throws -> [ViewDatabaseTableNames:Int] {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }
        
        return [
            .addresses: try db.scalar(self.addresses.count),
            .authors:  try db.scalar(self.authors.count),
            .messages:  try db.scalar(self.msgs.count),
            .abouts:    try db.scalar(self.abouts.count),
            .contacts:  try db.scalar(self.contacts.count),
            .privates: try db.scalar(self.msgs.filter(colDecrypted==true).count),
            .posts:     try db.scalar(self.posts.count),
            .votes:     try db.scalar(self.votes.count)
        ]
    }
    
    func stats(table: ViewDatabaseTableNames) throws -> Int {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }
        
        var cnt: Int = 0
        switch table {
            case .addresses: cnt = try db.scalar(self.addresses.count)
            case .authors:  cnt = try db.scalar(self.authors.count)
            case .messages: cnt = try db.scalar(self.msgs.count)
            case .messagekeys: cnt = Int(try self.lastReceivedSeq())
            case .abouts:   cnt = try db.scalar(self.abouts.count)
            case .contacts: cnt = try db.scalar(self.contacts.count)
            case .privates: cnt = try db.scalar(self.msgs.filter(colDecrypted==true).count)
            case .posts:    cnt = try db.scalar(self.posts.count)
            case .votes:    cnt = try db.scalar(self.votes.count)
            default: throw ViewDatabaseError.unknownTable(table)
        }
        return cnt
    }
    
    // helper to get some counts for pagination
    func statsForRootPosts(onlyFollowed: Bool = false) throws -> Int {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }
        var qry = self.posts
            .join(self.msgs, on: self.msgs[colMessageID] == self.posts[colMessageRef])
            .filter(colMsgType == "post")
            .filter(colIsRoot == true)
            .filter(colHidden == false)
            .filter(colDecrypted == false)
        
        if onlyFollowed {
            qry = try self.filterOnlyFollowedPeople(qry: qry)
        } else {
            qry = try self.filterNotFollowingPeople(qry: qry)
        }
        return try db.scalar(qry.count)
    }

    // posts for a feed
    func stats(for feed: FeedIdentifier) throws -> Int {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }
        do {
            let authorID = try self.authorID(of: feed, make: false)
            let theirRootPosts = try db.scalar(self.posts
                .join(self.msgs, on: self.msgs[colMessageID] == self.posts[colMessageRef])
                .filter(colAuthorID == authorID)
                .filter(colIsRoot == true)
                .count)

            return theirRootPosts
        } catch {
            Log.optional(GoBotError.duringProcessing("stats for feed failed", error))
            return 0
        }
    }
    
    func lastReceivedTimestamp() throws -> Double {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }
        
        if let timestamp = try db.scalar(self.msgs.select(colReceivedAt.max)) {
            return timestamp
        }
        
        return -1

    }
    
    
    
    func lastReceivedSeq() throws -> Int64 {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }
        
        let rxMaybe = Expression<Int64?>("rx_seq")
        if let rx = try db.scalar(self.msgs.select(rxMaybe.max)) {
            return rx
        }
        
        return -1
    }
    
    func minimumReceivedSeq() throws -> Int64 {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }
        
        let rxMaybe = Expression<Int64?>("rx_seq")
        if let rx = try db.scalar(self.msgs.select(rxMaybe.min)) {
            return rx
        }
        
        return -1
    }
    
    // MARK: pubs

    func getAllKnownPubs() throws -> [KnownPub] {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }

        let qry = self.addresses
           .join(self.authors, on: self.authors[colID] == self.addresses[colAboutID])
           .order(colWorkedLast.desc)

        return try db.prepare(qry).map { row in
            var workedWhen = "not yet"
            let workedLastMaybe = try? row.get(colWorkedLast)
            if  let didWork = workedLastMaybe {
                workedWhen = didWork.shortDateTimeString
            }

            var redeemedDate: Date?
            if let redeemedTimestamp = try row.get(colRedeemed) {
                redeemedDate = Date(timeIntervalSince1970: redeemedTimestamp / 1000)
            }
            
            return KnownPub(
                AddressID: try row.get(colAddressID),
                ForFeed: try row.get(colAuthor),
                Address: try row.get(colAddress),
                InUse: try row.get(colUse),
                WorkedLast: workedWhen,
                LastError: try row.get(colLastErr),
                redeemed: redeemedDate
            )
        }
    }
    
    func getRedeemedPubs() throws -> [Pub] {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }

        let qry = self.msgs
           .join(self.pubs, on: self.pubs[colMessageRef] == self.msgs[colMessageID])
            .where(self.msgs[colAuthorID] == currentUserID)
            .where(self.msgs[colMsgType] == "pub")

        return try db.prepare(qry).map { row in
            let host = try row.get(colHost)
            let port = try row.get(colPort)
            let key = try row.get(colKey)
            
            return Pub(type: .pub,
                       address: PubAddress(key: key,
                                           host: host,
                                           port: UInt(port)))
        }
    }
    
    // MARK: moderation / delete
    
    func updateBlockedContent(_ blocked: [String]) throws -> [FeedIdentifier] {
        guard let db = self.openDB else { throw ViewDatabaseError.notOpen }

        var matchedAuthorRefs: [FeedIdentifier] = []
        try db.transaction {
            /// 1. unhide previous content
            /// unhide previous blocked entries to support appeal process, for instance
            /// important to not over-rule user decision to block someone
            var blockedMsgs: [Int64] = []
            var blockedAuthors: [Int64] = []

            let blockedContentQry = try db.prepare(self.currentBlockedContent)
            for bc in blockedContentQry {
                let id = try bc.get(colID)
                switch try bc.get(colIDType) {
                case 0: blockedMsgs.append(id)
                case 1: blockedAuthors.append(id)
                default: fatalError("unhandled content type")
                }
            }

            let blockedMsgQry = self.msgs.filter(blockedMsgs.contains(colMessageID))
            try db.run(blockedMsgQry.update(colHidden <- false))

            let blockedAuthorsQry = self.msgs.filter(blockedAuthors.contains(colAuthorID))
            try db.run(blockedAuthorsQry.update(colHidden <- false))

            /// 2. set all matched messages to hidden

            // look for blocked IDs in msgs
            let matchedMsgsQry = self.msgKeys
                .join(self.msgs, on: colID == self.msgs[colMessageID])
                .filter(blocked.contains(colHashedKey))

            // keep ids for next unhide
            let matchedMsgIDs = try db.prepare(matchedMsgsQry.select(colID)).map { row in
                return row[colID]
            }

            // insert in current blocked for next unhide
            for id in matchedMsgIDs {
                try db.run(self.currentBlockedContent.insert(colID <- id, colIDType <- 0))
            }
            try db.run(self.msgs.filter(matchedMsgIDs.contains(colMessageID)).update(colHidden <- true))

            // now look for authors
            let matchedAuthors = try db.prepare(self.authors.filter(blocked.contains(colHashedKey))).map { row in
                // (@ref, num id)
                // we need the ID for gobot
                return (row[colAuthor], row[colID])
            }

            matchedAuthorRefs = matchedAuthors.map { return $0.0 }

            // insert in current blocked for next unhide
            for (_, id) in matchedAuthors {
                try db.run(self.currentBlockedContent.insert(colID <- id, colIDType <- 1))
                try db.run(self.msgs.filter(colAuthorID == id).update(colHidden <- true))
            }
        }

        // null content on sbot and add replicate block call
        return matchedAuthorRefs
    }

    func hide(allFrom author: FeedIdentifier) throws {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }
        let authorID = try self.authorID(of: author, make: false)
        let byAuthorQry = self.msgs.filter(colAuthorID == authorID)
        try db.run(byAuthorQry.update(colHidden <- true))
    }
    
    func unhide(for author: FeedIdentifier) throws {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }
        let authorID = try self.authorID(of: author, make: false)
        let byAuthorQry = self.msgs.filter(colAuthorID == authorID)
        try db.run(byAuthorQry.update(colHidden <- false))
    }

    func delete(allFrom author: Identity) throws {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }
        let authorID = try self.authorID(of: author, make: false)

        try db.transaction {
            try self.deleteNoTransaction(allFrom: authorID)
        }
    }

    private func deleteNoTransaction(allFrom authorID: Int64) throws {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }

        // all from abouts
        try db.run(self.abouts.filter(colAuthorID == authorID).delete())

        // all from contacts
        try db.run(self.contacts.filter(colAuthorID == authorID).delete())

        // all their messages
        let allMsgsQry = self.msgs
            .select(colMessageID, colRXseq)
            .filter(colAuthorID == authorID)
            .order(colRXseq.asc)
        let allMessages = Array(try db.prepare(allMsgsQry))

        // delete message from all specialized tables
        let messageTables = [
            self.posts,
            self.post_blobs,
            self.tangles,
            self.mentions_msg,
            self.mentions_feed,
            self.mentions_image,
            self.privateRecps,
            self.addresses,
            self.votes,
            self.channelAssigned,
        ]

        // convert rows to [Int64] for (msg_id IN [x1,...,xN]) below
        let msgIDs = try allMessages.map { row in
            return try row.get(colMessageID)
        }
        for tbl in messageTables {
            let qry = tbl.filter(msgIDs.contains(colMessageRef)).delete()
            try db.run(qry)
        }

        // delete reply branches
        // refactor idea: could rename 'branch' column to msgRef
        // then branches can be part of messageTables
        try db.run(self.branches.filter(msgIDs.contains(colBranch)).delete())

        // delete the base messages
        try db.run(self.msgs.filter(msgIDs.contains(colMessageID)).delete())

        // update %fakemsg if feed is at the end of the receive log
        if let lastMsgRX = try allMessages.last?.get(colRXseq) {
            let lastReceived = try self.lastReceivedSeq()
            if lastMsgRX == lastReceived {
                try self.updateFakeMsg(seq: lastMsgRX)
            }
        }
    }

    func delete(message: MessageIdentifier) throws {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }
        try db.transaction {
            try self.deleteNoTransact(message: message)
        }
    }

    // this is just here so that the fill loop can use it without a transaction
    private func deleteNoTransact(message: MessageIdentifier) throws {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }
        let msgID = try self.msgID(of: message, make: false)
        let lastRX = try self.lastReceivedSeq()
        let rxSeq = try db.scalar(self.msgs.select(colRXseq).filter(colMessageID == msgID))
        if lastRX == rxSeq {
            try self.updateFakeMsg(seq: rxSeq)
        }
        // delete message from all specialized tables
        let messageTables = [
            self.posts,
            self.post_blobs,
            self.tangles,
            self.mentions_msg,
            self.mentions_feed,
            self.mentions_image,
            self.privateRecps,
        ]
        for t in messageTables {
            try db.run(t.filter(colMessageRef == msgID).delete())
        }
        try db.run(self.branches.filter(colBranch == msgID).delete())
        try db.run(self.msgs.filter(colMessageID == msgID).delete())
    }

    // copy RX log sequence to %fakemsg so that it isn't re-fetched if it is at the end
    private func updateFakeMsg(seq: Int64) throws {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }
        try db.run(self.msgs.insert(or: .replace,
            colRXseq <- seq,
            colMessageID <- try self.msgID(of: "%fakemsg.wrong", make: true),
            colAuthorID <- try self.authorID(of: "@fakeauthor.wrong", make: true),
            colSequence <- 0,
            colMsgType <- .unsupported,
            colReceivedAt <- 0,
            colClaimedAt <- 0))
    }

    // MARK: abouts
    
    func getName(feed: Identifier) throws -> String? {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }
        
        var aboutID: Int64
        if let authorRow = try db.pluck(self.authors.filter(colAuthor == feed)) {
            aboutID = authorRow[colID]
        } else {
            throw ViewDatabaseError.unknownAuthor(feed)
        }
        let qry = self.abouts
            .join(self.authors, on: colAuthorID == self.authors[colID])
            .join(self.msgs, on: colMessageRef == self.msgs[colMessageID])
            .filter(colAboutID == aboutID)
            .filter(colAuthor == feed)
        
        for names in try db.prepare(qry) {
            if let n = names[colName] {
                return n
            }
        }
        return nil
    }
    
    func getAbout(for id: Identifier) throws -> About? {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }
        
        let aboutID = try self.authorID(of: id)
        
        let qry = self.abouts
            .join(self.msgs, on: colMessageRef == self.msgs[colMessageID])
            .filter(colAboutID == aboutID)
        
        let msgs: [About] = try db.prepare(qry).map { row in
            return About(about: id,
                     name: try row.get(colName),
                     description: try row.get(colDescr),
                     imageLink: try row.get(colImage),
                     publicWebHosting: try row.get(colPublicWebHosting)
                 )
        }
        return msgs.first
    }
    
    func getAbouts() throws -> [About] {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }
        
        let qry = self.abouts
            .join(self.authors, on: colID == self.abouts[colAboutID])
 //           .filter(colAboutID == aboutID)
        
        var abouts: [About] = []
        
        let aboutsQry = try db.prepare(qry)
        for about in aboutsQry {
            let about = About(about: try about.get(colAuthor),
                     name: try about.get(colName),
                     description: try about.get(colDescr),
                     imageLink: try about.get(colImage)
                 )
            abouts += [about]
        }
        return abouts
    }
    
    // MARK: follows and blocks
    
    // who is this feed following?
    func getFollows(feed: Identity) throws -> [Identity] {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }
        
        let authorID = try self.authorID(of: feed, make: false)
        
        let qry = self.contacts
            .select(colAuthor.distinct)
            .join(self.authors, on: colContactID == self.authors[colID])
            .filter(colAuthorID == authorID)
            .filter(colContactState == 1)
        
        var follows: [FeedIdentifier] = []
    
        let followsQry = try db.prepare(qry)
        for follow in followsQry {
            let authorID: Identity = try follow.get(colAuthor.distinct)
            follows += [authorID]
        }
        
        return follows
    }

    func getFollows(feed: Identity) throws -> [About] {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }

        let authorID = try self.authorID(of: feed, make: false)

        let qry = self.contacts
            .select(colAuthor.distinct, self.abouts[colName], self.abouts[colDescr], self.abouts[colImage])
            .join(self.authors, on: colContactID == self.authors[colID])
            .join(.leftOuter, self.abouts, on: colContactID == self.abouts[colAboutID])
            .filter(colAuthorID == authorID)
            .filter(colContactState == 1)

        var follows: [About] = []

        let followsQry = try db.prepare(qry)
        for follow in followsQry {
            let authorID: Identity = try follow.get(colAuthor.distinct)
            let name: String? = try follow.get(self.abouts[colName])
            let description: String? = try follow.get(colDescr)
            let imageLink: String? = try follow.get(colImage)
            let about = About(about: authorID, name: name, description: description, imageLink: imageLink)
            follows += [about]
        }

        return follows
    }
    
    // who is following this feed
    func followedBy(feed: Identity) throws -> [Identity] {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }
        
        let feedID = try self.authorID(of: feed, make: false)
        
        let qry = self.contacts
            .select(colAuthor.distinct)
            .join(self.authors, on: colAuthorID == self.authors[colID])
            .filter(colContactID == feedID)
            .filter(colContactState == 1)
            .order(colClaimedAt.desc)
        
        var who: [Identity] = []
        
        let followsQry = try db.prepare(qry)
        for follow in followsQry {
            let authorID: Identity = try follow.get(colAuthor.distinct)
            who += [authorID]
        }
        
        return who
    }

    func followedBy(feed: Identity) throws -> [About] {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }

        let feedID = try self.authorID(of: feed, make: false)

        let qry = self.contacts
            .select(colAuthor.distinct, self.abouts[colName], self.abouts[colDescr], self.abouts[colImage])
            .join(self.authors, on: colAuthorID == self.authors[colID])
            .join(.leftOuter, self.abouts, on: colAuthorID == self.abouts[colAboutID])
            .filter(colContactID == feedID)
            .filter(colContactState == 1)
            .order(colClaimedAt.desc)

        var who: [About] = []

        let followsQry = try db.prepare(qry)
        for follow in followsQry {
            let authorID: Identity = try follow.get(colAuthor.distinct)
            let name: String? = try follow.get(self.abouts[colName])
            let description: String? = try follow.get(colDescr)
            let imageLink: String? = try follow.get(colImage)
            let about = About(about: authorID, name: name, description: description, imageLink: imageLink)
            who += [about]
        }

        return who
    }
    
    // returns the same (who follows this feed) list as above
    // but returns a [KeyValue] (with timestamp) instead of just the public key reference
    func followedBy(feed: Identity, limit: Int = 100) throws -> [KeyValue] {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }

        let feedID = try self.authorID(of: feed, make: false)

        // TODO: change latest view to add reference to latest message (for timestamp)
        let qry = self.contacts
            .join(self.msgs, on: self.msgs[colMessageID] == self.contacts[colMessageRef])
            .join(self.msgKeys, on: self.msgKeys[colID] == self.contacts[colMessageRef])
            .join(self.authors, on: self.authors[colID] == self.contacts[colAuthorID])
            .join(self.abouts, on: self.abouts[colAboutID] == self.contacts[colAuthorID])
            .filter(colContactID == feedID)
            .filter(colContactState == 1)
            .order(colClaimedAt.desc)
            .group(colAuthor)
            .limit(limit)

        return try db.prepare(qry).map { row in
            // tried 'return try row.decode()'
            // but failed - see https://github.com/VerseApp/ios/issues/29

            let msgAuthor = try row.get(colAuthor)
            let c = Contact(contact: feed, following: true)


            let v = Value(
                author: msgAuthor,
                content: Content(from: c),
                hash: "sha256", // only currently supported
                previous: nil, // TODO: .. needed at this level?
                sequence: try row.get(colSequence),
                signature: "verified_by_go-ssb",
                timestamp: try row.get(colClaimedAt)
            )

            var keyValue = KeyValue(
                key: try row.get(colKey),
                value: v,
                timestamp: try row.get(colReceivedAt)
            )

            keyValue.metadata.author.about = About(
                    about: msgAuthor,
                    name: try row.get(self.abouts[colName]),
                    description: try row.get(colDescr),
                    imageLink: try row.get(colImage)
            )
            return keyValue
        }
    }

    // who is this feed blocking
    func getBlocks(feed: Identity) throws -> [Identity] {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }
        
        let authorID = try self.authorID(of: feed, make: false)
        
        let qry = self.contacts
            .select(colAuthor)
            .join(self.authors, on: colContactID == self.authors[colID])
            .filter(colAuthorID == authorID)
            .filter(colContactState == -1)
        
        var follows: [FeedIdentifier] = []
        
        for follow in try db.prepare(qry) {
            let followID = try follow.get(colAuthor)
            follows += [followID]
        }
        
        return follows
    }
    
    func blockedBy(feed: Identity) throws -> [Identity] {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }
        
        let authorID = try self.authorID(of: feed, make: false)
        
        let qry = self.contacts
            .select(colAuthor)
            .join(self.authors, on: colAuthorID == self.authors[colID])
            .filter(colContactID == authorID)
            .filter(colContactState == -1)
        
        var lst: [FeedIdentifier] = []
        for block in try db.prepare(qry) {
            lst += [try block.get(colAuthor)]
        }
        
        return lst
    }
    
    // who is this one following and who is follwing back? aka friends
    func getBidirectionalFollows(feed: Identity) throws -> [Identity] {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }
        
        var authorID: Int64
        if let authorRow = try db.pluck(self.authors.filter(colAuthor == feed)) {
            authorID = authorRow[colID]
        } else {
            throw ViewDatabaseError.unknownAuthor(feed)
        }
        
        let stmt = try db.prepare("""
        SELECT author FROM authors
        WHERE id in (
            SELECT author_id FROM contacts
            WHERE
                state = 1
            AND
                contact_id == (?)
            AND
                author_id in (
                    SELECT contact_id FROM contacts WHERE author_id == (?) AND state = 1
                )
        )
        """)
        
        var who: [Identity] = []
        for f in try stmt.run(authorID, authorID) {
            let friend: Identity = "\(f[0]!)"
            who += [friend]
        }
        return who
    }

    // MARK: pagination
    // returns a pagination proxy for the home (or recent) view
    func paginated(onlyFollowed: Bool) throws -> (PaginatedKeyValueDataProxy) {
        let src = try RecentViewKeyValueSource(with: self, onlyFollowed: onlyFollowed)
        return try PaginatedPrefetchDataProxy(with: src)
    }

    func paginated(feed: Identity) throws -> (PaginatedKeyValueDataProxy) {
        let src = try FeedKeyValueSource(with: self, feed: feed)
        return try PaginatedPrefetchDataProxy(with: src)
    }

    // MARK: recent
    func recentPosts(limit: Int, offset: Int? = nil, wantPrivate: Bool = false, onlyFollowed: Bool = true) throws -> KeyValues {
        guard let _ = self.openDB else {
            throw ViewDatabaseError.notOpen
        }
        
        var qry = self.basicRecentPostsQuery(limit: limit, wantPrivate: wantPrivate, offset: offset)
            .order(colClaimedAt.desc)
        
        if onlyFollowed {
            qry = try self.filterOnlyFollowedPeople(qry: qry)
        } else {
            qry = try self.filterNotFollowingPeople(qry: qry)
        }
        
        let feedOfMsgs = try self.mapQueryToKeyValue(qry: qry)
            
        return try self.addNumberOfPeopleReplied(msgs: feedOfMsgs)
    }
    
    // MARK: common query constructors

    private func basicRecentPostsQuery(limit: Int, wantPrivate: Bool, onlyRoots: Bool = true, offset: Int? = nil) -> Table {
        var qry = self.msgs
            .join(self.posts, on: self.posts[colMessageRef] == self.msgs[colMessageID])
            .join(.leftOuter, self.tangles, on: self.tangles[colMessageRef] == self.msgs[colMessageID])
            .join(self.msgKeys, on: self.msgKeys[colID] == self.msgs[colMessageID])
            .join(self.authors, on: self.authors[colID] == self.msgs[colAuthorID])
            .join(.leftOuter, self.abouts, on: self.abouts[colAboutID] == self.msgs[colAuthorID])
            .filter(colMsgType == "post")           // only posts (no votes or contact messages)
            .filter(colDecrypted == wantPrivate)
            .filter(colHidden == false)

        if let offset = offset {
            qry = qry.limit(limit, offset: offset)
        } else {
            qry = qry.limit(limit)
        }

        // TODO: this is a very handy query but also used in a lot of places
        // maybe should be split apart into a wrapper like filterOnlyFollowedPeople which is just func(Table) -> Table
        if onlyRoots {
            qry = qry.filter(colIsRoot == true)   // only thread-starting posts (no replies)
        }
        return qry
    }

    // wraps the query with only authored people by that the current user follows
    // TODO: does a manual sub-query (that could be cached - or pushed down even into the main query with raw sql)
    private func filterOnlyFollowedPeople(qry: Table) throws -> Table {
        // get the list of people that the active user follows
        let myFollowsQry = self.contacts
            .select(colContactID)
            .filter(colAuthorID == self.currentUserID)
            .filter(colContactState == 1)
        var myFollows: [Int64] = [self.currentUserID] // and from self as well
        for row in try self.openDB!.prepare(myFollowsQry) {
            myFollows.append(row[colContactID])
        }
        return qry.filter(myFollows.contains(colAuthorID))    // authored by one of our follows
    }
    
    
    private func filterNotFollowingPeople(qry: Table) throws -> Table {
        // get the list of people that the active user follows
        let myFollowsQry = self.contacts
            .select(colContactID)
            .filter(colAuthorID == self.currentUserID)
            .filter(colContactState == 1)
        var myFollows: [Int64] = [self.currentUserID] // and from self as well
        for row in try self.openDB!.prepare(myFollowsQry) {
            myFollows.append(row[colContactID])
        }
        return qry.filter(!(myFollows.contains(colAuthorID)))    // authored by one of our follows
    }
    //table.filter(!(array.contains(id)))

    private func mapQueryToKeyValue(qry: Table) throws -> [KeyValue] {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }
        let colRootMaybe = Expression<Int64?>("root")

        // TODO: add switch over type (to support contact, vote, gathering, etc..)

        return try db.prepare(qry).compactMap { row in
            // tried 'return try row.decode()'
            // but failed - see https://github.com/VerseApp/ios/issues/29
            
            let msgID = try row.get(colMessageID)
            
            let msgKey = try row.get(colKey)
            let msgAuthor = try row.get(colAuthor)

            var c: Content
               
            let type = try row.get(self.msgs[colMsgType])
            
            switch type {
            case ContentType.post.rawValue:
                
                var rootKey: Identifier?
                if let rootID = try row.get(colRootMaybe) {
                    rootKey = try self.msgKey(id: rootID)
                }
                
                let p = Post(
                    blobs: try self.loadBlobs(for:msgID),
                    mentions: try self.loadMentions(for: msgID),
                    root: rootKey,
                    text: try row.get(colText)
                )
                
                c = Content(from: p)
                
            case ContentType.vote.rawValue:
                
                let lnkID = try row.get(colLinkID)
                let lnkKey = try self.msgKey(id: lnkID)
                
                let rootID = try row.get(colRoot)
                let rootKey = try self.msgKey(id: rootID)
                
                
                let cv = ContentVote(
                    link: lnkKey,
                    value: try row.get(colValue),
                    root: rootKey,
                    branches: [] // TODO: branches for root
                )
                
                c = Content(from: cv)
            case ContentType.contact.rawValue:
                if let state = try? row.get(colContactState) {
                    let following = state == 1
                    let cc = Contact(contact: msgAuthor, following: following)
                    
                    c = Content(from: cc)
                } else {
                    // Contacts stores only the latest message
                    // So, an old follow that was later unfollowed won't appear here.
                    return nil
                }
            default:
                throw ViewDatabaseError.unexpectedContentType(type)
            }
            
            let v = Value(
                author: msgAuthor,
                content: c,
                hash: "sha256", // only currently supported
                previous: nil, // TODO: .. needed at this level?
                sequence: try row.get(colSequence),
                signature: "verified_by_go-ssb",
                timestamp: try row.get(colClaimedAt)
            )
            var keyValue = KeyValue(
                key: msgKey,
                value: v,
                timestamp: try row.get(colReceivedAt)
            )
            keyValue.metadata.author.about = About(
                about: msgAuthor,
                name: try row.get(self.abouts[colName]),
                description: try row.get(colDescr),
                imageLink: try row.get(colImage)
            )
            keyValue.metadata.isPrivate = try row.get(colDecrypted)
            return keyValue
        }
    }
    
    // MARK: replies

    // turns an array of messages into an array of (msg, #people replied)
    private func addNumberOfPeopleReplied(msgs: [KeyValue]) throws -> KeyValues {
        var r: KeyValues = []
        for (index, _) in msgs.enumerated() {
            var msg = msgs[index]
            let msgID = try self.msgID(of: msg.key)

            let replies = self.tangles
                .select(colAuthorID.distinct, colAuthor, colName, colDescr, colImage)
                .join(self.msgs, on: self.msgs[colMessageID] == self.tangles[colMessageRef])
                .join(self.authors, on: self.msgs[colAuthorID] == self.authors[colID])
                .join(self.abouts, on: self.authors[colID] == self.abouts[colAboutID])
                .filter(colMsgType == ContentType.post.rawValue || colMsgType == ContentType.vote.rawValue)
                .filter(colRoot == msgID)

            let count = try self.openDB!.scalar(replies.count)

            var abouts: [About] = []
            for row in try self.openDB!.prepare(replies.limit(3, offset: 0)) {
                let about = About(about: row[colAuthor],
                                  name: row[colName],
                                  description: row[colDescr],
                                  imageLink: row[colImage])
                abouts += [about]
            }

            msg.metadata.replies.count = count
            msg.metadata.replies.abouts = abouts
            r.append(msg)
        }
        return r
    }

    // get all messages that replied to msg
    // TODO: ensure order by sorting by tangle heads
    // bug: currently squashing multiple branches
    func getRepliesTo(thread msg: MessageIdentifier) throws -> [KeyValue] {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }
        
        let msgID = try self.msgID(of: msg)
        let qry = self.tangles
            .join(self.msgKeys, on: self.msgKeys[colID] == self.tangles[colMessageRef])
            .join(self.msgs, on: self.msgs[colMessageID] == self.tangles[colMessageRef])
            .join(self.authors, on: self.authors[colID] == self.msgs[colAuthorID])
            .join(self.abouts, on: self.abouts[colAboutID] == self.msgs[colAuthorID])
            .join(.leftOuter, self.posts, on: self.posts[colMessageRef] == self.tangles[colMessageRef])
            .join(.leftOuter, self.votes, on: self.votes[colMessageRef] == self.tangles[colMessageRef])
            .filter(colMsgType == ContentType.post.rawValue || colMsgType == ContentType.vote.rawValue )
            .filter(colRoot == msgID)
            .filter(colHidden == false)
            .order(colClaimedAt.asc)
        
        // making this a two-pass query until i can figure out how to dynamlicly join based on type

        let msgs :[KeyValue] = try db.prepare(qry).map { row in
            // tried 'return try row.decode()'
            // but failed - see https://github.com/VerseApp/ios/issues/29
            
            let msgID = try row.get(colMessageID)
            let msgKey = try row.get(colKey)
            let msgAuthor = try row.get(colAuthor)
            
            var c: Content
            
            let tipe = try row.get(colMsgType)
            switch tipe {
            case ContentType.post.rawValue:
                
                let rootID = try row.get(colRoot)
                let rootKey = try self.msgKey(id: rootID)
                
                let p = Post(
                    blobs: try self.loadBlobs(for:msgID),
                    mentions: try self.loadMentions(for: msgID),
                    root: rootKey,
                    text: try row.get(colText)
                )
                
                c = Content(from: p)
                
            case ContentType.vote.rawValue:
                
                let lnkID = try row.get(colLinkID)
                let lnkKey = try self.msgKey(id: lnkID)
                
                let rootID = try row.get(colRoot)
                let rootKey = try self.msgKey(id: rootID)
                

                let cv = ContentVote(
                    link: lnkKey,
                    value: try row.get(colValue),
                    root: rootKey,
                    branches: [] // TODO: branches for root
                )

                c = Content(from: cv)
            
            default:
                throw ViewDatabaseError.unexpectedContentType(tipe)
            }
            
         
            let v = Value(
                author: msgAuthor,
                content: c,
                hash: "sha256", // only currently supported
                previous: nil, // TODO: .. needed at this level?
                sequence: try row.get(colSequence),
                signature: "verified_by_go-ssb",
                timestamp: try row.get(colClaimedAt)
            )
            var kv = KeyValue(
                key: msgKey,
                value: v,
                timestamp: try row.get(colReceivedAt)
            )
            kv.metadata.author.about = About(
                about: msgAuthor,
                name: try row.get(self.abouts[colName]),
                description: try row.get(colDescr),
                imageLink: try row.get(colImage)
            )
            kv.metadata.isPrivate = try row.get(colDecrypted)
            return kv
        }
        return msgs
    }

    // finds all the posts from current user that are not replies.
    // then looks for all replies to these threads.
    // TOOD: pagination
    func getRepliesToMyThreads(limit: Int = 50) throws -> [KeyValue] {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }

        // reminder: SQLite.swift can't do subquerys
        // https://app.asana.com/0/0/1133029620163798/f

        // posts by user that are not replies
        let colMaybeRoot = Expression<Int64?>("root")
        let threadsStartedByUserQry = self.msgs
            .select(colMessageID)
            .join(.leftOuter, self.tangles, on: self.msgs[colMessageID] == self.tangles[colMessageRef])
            .filter(colAuthorID == self.currentUserID)
            .filter(colMsgType == "post")
            .filter(colMaybeRoot == nil)
            .filter(colHidden == false)
            .limit(limit)

        var threadIDs: [Int64] = [] // and from self as well
        for row in try db.prepare(threadsStartedByUserQry) {
            threadIDs.append(row[colMessageID])
        }

        let repliesQry = self.basicRecentPostsQuery(limit: limit, wantPrivate: false, onlyRoots: false)
            .filter(threadIDs.contains(colRoot))

        return try self.mapQueryToKeyValue(qry: repliesQry)
    }

    func mentions(limit: Int = 200, wantPrivate: Bool = false, onlyImages: Bool = true) throws -> KeyValues {
        guard let _ = self.openDB else {
            throw ViewDatabaseError.notOpen
        }
        let qry = self.mentions_feed
            .join(self.msgs, on: self.msgs[colMessageID] == self.mentions_feed[colMessageRef])
            .join(self.posts, on: self.posts[colMessageRef] == self.msgs[colMessageID])
            .join(self.msgKeys, on: self.msgKeys[colID] == self.msgs[colMessageID])
            .join(self.authors, on: self.authors[colID] == self.msgs[colAuthorID])
            .join(self.abouts, on: self.abouts[colAboutID] == self.msgs[colAuthorID])
            .join(.leftOuter, self.tangles, on: self.tangles[colMessageRef] == self.msgs[colMessageID])
            .filter(colFeedID == self.currentUserID)
            .filter(colAuthorID != self.currentUserID)
            .filter(colHidden == false)
            .order(colClaimedAt.desc)
            .limit(limit)
        
        
        
        return try self.mapQueryToKeyValue(qry: qry)
    }
    
    func reports(limit: Int = 200) throws -> [Report] {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }
        let qry = self.reports
            .join(self.msgs, on: self.msgs[colMessageID] == self.reports[colMessageRef])
            .join(.leftOuter, self.posts, on: self.posts[colMessageRef] == self.msgs[colMessageID])
            .join(.leftOuter, self.contacts, on: self.contacts[colMessageRef] == self.msgs[colMessageID])
            .join(.leftOuter, self.votes, on: self.votes[colMessageRef] == self.msgs[colMessageID])
            .join(self.msgKeys, on: self.msgKeys[colID] == self.msgs[colMessageID])
            .join(self.authors, on: self.authors[colID] == self.msgs[colAuthorID])
            .join(self.abouts, on: self.abouts[colAboutID] == self.msgs[colAuthorID])
            .join(.leftOuter, self.tangles, on: self.tangles[colMessageRef] == self.msgs[colMessageID])
        
        let filteredQuery = qry.filter(self.reports[colAuthorID] == self.currentUserID)
            
        let sortedQuery = filteredQuery.order(colCreatedAt.desc)
        
        return try db.prepare(sortedQuery).compactMap { row in
            // tried 'return try row.decode()'
            // but failed - see https://github.com/VerseApp/ios/issues/29
            
            let msgID = try row.get(colMessageID)
            
            let msgKey = try row.get(colKey)
            let msgAuthor = try row.get(colAuthor)

            var c: Content
               
            let type = try row.get(self.msgs[colMsgType])
            
            switch type {
            case ContentType.post.rawValue:
                
                var rootKey: Identifier?
                let colRootMaybe = Expression<Int64?>("root")
                
                if let rootID = try row.get(colRootMaybe) {
                    rootKey = try self.msgKey(id: rootID)
                }
                
                let p = Post(
                    blobs: try self.loadBlobs(for:msgID),
                    mentions: try self.loadMentions(for: msgID),
                    root: rootKey,
                    text: try row.get(colText)
                )
                
                c = Content(from: p)
                
            case ContentType.vote.rawValue:
                
                let lnkID = try row.get(colLinkID)
                let lnkKey = try self.msgKey(id: lnkID)
                
                let rootID = try row.get(colRoot)
                let rootKey = try self.msgKey(id: rootID)
                
                
                let cv = ContentVote(
                    link: lnkKey,
                    value: try row.get(colValue),
                    root: rootKey,
                    branches: [] // TODO: branches for root
                )
                
                c = Content(from: cv)
            case ContentType.contact.rawValue:
                if let state = try? row.get(colContactState) {
                    let following = state == 1
                    let cc = Contact(contact: msgAuthor, following: following)
                    
                    c = Content(from: cc)
                } else {
                    // Contacts stores only the latest message
                    // So, an old follow that was later unfollowed won't appear here.
                    return nil
                }
            default:
                throw ViewDatabaseError.unexpectedContentType(type)
            }
            
            let v = Value(
                author: msgAuthor,
                content: c,
                hash: "sha256", // only currently supported
                previous: nil, // TODO: .. needed at this level?
                sequence: try row.get(colSequence),
                signature: "verified_by_go-ssb",
                timestamp: try row.get(colClaimedAt)
            )
            var keyValue = KeyValue(
                key: msgKey,
                value: v,
                timestamp: try row.get(colReceivedAt)
            )
            keyValue.metadata.author.about = About(
                about: msgAuthor,
                name: try row.get(self.abouts[colName]),
                description: try row.get(colDescr),
                imageLink: try row.get(colImage)
            )
            keyValue.metadata.isPrivate = try row.get(colDecrypted)
            
            let rawReportType = try row.get(self.reports[colReportType])
            let reportType = ReportType(rawValue: rawReportType)!
            
            let createdAtTimestamp = try row.get(colCreatedAt)
            let createdAt = Date(timeIntervalSince1970: createdAtTimestamp / 1000)
            
            let report = Report(authorIdentity: "undefined",
                                messageIdentifier: msgKey,
                                reportType: reportType,
                                createdAt: createdAt,
                                keyValue: keyValue)
            return report
        }
    }

    func feed(for identity: Identity, limit: Int = 100, offset: Int? = nil) throws -> KeyValues {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }
        let timeStart = CFAbsoluteTimeGetCurrent()
        let feedAuthorID = try self.authorID(of: identity, make: false)
        
        let doWeBlockThemQry = self.contacts
            .filter(colAuthorID == self.currentUserID)
            .filter(colContactID == feedAuthorID)
            .filter(colContactState == -1)
        if try db.pluck(doWeBlockThemQry) != nil {
            throw GoBotError.duringProcessing("user blocked", ViewDatabaseError.unknownAuthor(identity))
        }

        let postsQry = self.basicRecentPostsQuery(
            limit: limit,
            wantPrivate: false,
            onlyRoots: true,
            offset: offset)
            .filter(colAuthorID == feedAuthorID)
            .order(colClaimedAt.desc)
            .filter(colHidden == false)

        let feedOfMsgs = try self.mapQueryToKeyValue(qry: postsQry)
        let msgs = try self.addNumberOfPeopleReplied(msgs: feedOfMsgs)
        let timeDone = CFAbsoluteTimeGetCurrent()
        print("\(#function) took \(timeDone-timeStart)")
        return msgs
    }

    func getAuthorOf(key: MessageIdentifier) throws -> Int64? {
        let msgId = try self.msgID(of: key, make: false)
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }
        
        let colAuthorID = Expression<Int64?>("colAuthorID")
        let authorID = try db.scalar(self.msgs
            .select(colAuthorID)
            .filter(colMessageID == msgId)
            .filter(colHidden == false))
        return authorID
    }
    
    func get(key: MessageIdentifier) throws -> KeyValue {
        let msgId = try self.msgID(of: key, make: false)
        // TODO: add 2nd signature to get message by internal ID
//        guard let db = self.openDB else {
//            throw ViewDatabaseError.notOpen
//        }
//        let msgId = try self.msgID(of: key, make: false)
//
//        return self.get(msgID: msgID)
//    }
//
//    func get(msgID: Int64) throws -> KeyValue {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }
        
        let colTypeMaybe = Expression<String?>("type")
        let typeMaybe = try db.scalar(self.msgs
            .select(colTypeMaybe)
            .filter(colMessageID == msgId)
            .filter(colHidden == false))

        guard let msgType = typeMaybe else {
            Log.unexpected(.botError, "[viewdb] should have type for this message: \(msgId): \(key)")
            throw ViewDatabaseError.unknownMessage(key)
        }
        
        guard let ct = ContentType(rawValue: msgType) else {
            throw ViewDatabaseError.unexpectedContentType(msgType)
        }

        switch ct {
            case .post:
                // TODO: fill in tangles
                let qry = self.msgs
                    .join(self.msgKeys, on: self.msgKeys[colID] == self.msgs[colMessageID])
                    .join(self.posts, on: self.posts[colMessageRef] == self.msgs[colMessageID])
                    .join(.leftOuter, self.tangles, on: self.tangles[colMessageRef] == self.msgs[colMessageID])
                    .join(self.authors, on: self.authors[colID] == self.msgs[colAuthorID])
                    .join(self.abouts, on: self.abouts[colAboutID] == self.msgs[colAuthorID])
                    .filter(colMessageID == msgId)
                    .limit(1)
                
                let kv = try self.mapQueryToKeyValue(qry: qry)
                
                if kv.count != 1 {
                    Log.unexpected(.botError, "[viewdb] could not find post after we had the type!?")
                    throw ViewDatabaseError.unknownMessage(key)
                }
                return kv[0]
            
        default:
            throw ViewDatabaseError.unhandledContentType(ct)
        }
    }
    
    // MARK: channels
    
    func hashtags() throws -> [Hashtag] {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }
        let qry = try db.prepare("""
        SELECT distinct( channels.name), count(*), messages.received_at 
        FROM "channels", "channel_assignments", "messages"
        WHERE (
            "messages"."msg_id" = "channel_assignments"."msg_ref"
            AND
            "channels"."id" = "channel_assignments"."chan_ref"
        )
        Group by channels.id
        ORDER BY "messages.received_at" ASC
        
        """)

        var channels: [Hashtag] = []
        
        for f in try qry.run() {
            let count = f[1] as! Int64
            let timestamp = f[2] as! Float64
            let hashtag = Hashtag(name: "\(f[0]!)", count: count, timestamp: timestamp)
            channels += [hashtag]
        }
        return channels
    }
    
    // TODO: pagination
    func messagesForHashtag(name: String) throws -> [KeyValue] {
        let cID = try self.channelID(from: name)

        let qry = self.channelAssigned
            .filter(colChanRef == cID)
            .join(self.msgKeys, on: self.msgKeys[colID] == self.channelAssigned[colMessageRef])
            .join(self.msgs, on: self.msgs[colMessageID] == self.channelAssigned[colMessageRef])
            .join(self.authors, on: self.authors[colID] == self.msgs[colAuthorID])
            .join(self.abouts, on: self.abouts[colAboutID] == self.msgs[colAuthorID])
            .join(.leftOuter, self.tangles, on: self.tangles[colMessageRef] == self.channelAssigned[colMessageRef])
            .join(.leftOuter, self.posts, on: self.posts[colMessageRef] == self.channelAssigned[colMessageRef])
            .order(colClaimedAt.desc)

        return try self.mapQueryToKeyValue(qry: qry)
    }
    
    private func channelID(from name: String, make: Bool = false) throws -> Int64 {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }
        var channelID: Int64
        if let chanRow = try db.pluck(self.channels.filter(colName == name)) {
            channelID = chanRow[colID]
        } else {
            if make {
                channelID = try db.run(self.channels.insert(
                    colName <- name
                ))
            } else {
                throw ViewDatabaseError.unknownAuthor(name)
            }
        }
        return channelID
    }

    private func getChannel(from id: Int64) throws -> Hashtag {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }

        let qry = self.channels
            .filter(colID == id)
            .limit(1)

        if let row = try db.pluck(qry) {
            guard let name = try row.get(colName) else {
                // TODO: use proper error
                throw ViewDatabaseError.unexpectedContentType("unnamed hashtag?!")
            }
            return Hashtag(name: name)
        } else {
            throw ViewDatabaseError.unknownReferenceID(id)
        }

    }

    // MARK: fill new messages
    
    private func fillAddress(msgID: Int64, msg: KeyValue) throws {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }
        
        guard let a = msg.value.content.address else {
            Log.info("[viewdb/fill] broken addr message: \(msg.key)")
            return
        }
        
        
        
        let authorID = try self.authorID(of: msg.value.author, make: true)
        
        try db.run(self.addresses.insert(or: .replace,
            colAboutID <- authorID,
            colAddress <- a.address
        ))
    }
    
    private func fillAbout(msgID: Int64, msg: KeyValue) throws {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }
        
        guard let a = msg.value.content.about else {
            Log.info("[viewdb/fill] broken about message: \(msg.key)")
            return
        }
        
        if a.about.sigil == .message {
            
            var chanID: Int64
            do {
                chanID = try self.msgID(of: a.about, make: false)
            } catch ViewDatabaseError.unknownMessage {
                // Log.info("viewdb/debug: type:about with about:\(a.about) for a msg we don't have (probably git-repo or gathering)")
                return
            }
            
            let chanFilter = self.channels.filter(colMessageRef == chanID)
            
            guard let chanName = a.name else {
                // Log.info("viewdb/debug: about msgkey without a name: \(msg.key) (probably gathering)")
                return
            }

            try db.run(chanFilter.update(
                colName <- chanName
            ))
        }
        
        if a.about != msg.value.author {
            // ignoring all abouts that are not self
            // TODO: breaks gatherings but we don't use them yet
            return
        }
        
        let aboutID = try self.authorID(of: a.about, make: true)
        
        let entry = self.abouts.filter(colAboutID == aboutID)
        let c = try db.scalar(entry.count)
        if c == 0 {
            try db.run(self.abouts.insert(
                colMessageRef <- msgID,
                colAboutID <- aboutID
            ))
        }
        
        if let name = a.name {
            try db.run(entry.update(
                colName <- name
            ))
        }
        if let img = a.image {
            try db.run(entry.update(
                colImage <- img.link
            ))
        }
        if let descr = a.description {
            try db.run(entry.update(
                colDescr <- descr
            ))
        }
        if let publicWebHosting = a.publicWebHosting {
            try db.run(entry.update(
                colPublicWebHosting <- publicWebHosting
            ))
        }
    }
    
    private func fillContact(msgID: Int64, msg: KeyValue) throws {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }
        
        guard let c = msg.value.content.contact else {
            Log.info("[viewdb/fill] broken contact message: \(msg.key)")
            return
        }
        
        let authorID = try self.authorID(of: msg.value.author, make: false)
        let contactID = try self.authorID(of: c.contact, make: true)
        
        var state: Int = 0
        
        let b = c.blocking ?? false
        let f = c.following ?? false
        
        if b && f {
            Log.info("[viewdb/fill] broken contact. both b & f: \(msg.key)")
            return
        }
        
        if b {
            state = -1
        }
        
        if f {
            state = 1
        }
        
        // should update existing relation but want tests first
        try db.run(self.contacts.insert(or: .replace,
            colAuthorID <- authorID,
            colContactID <- contactID,
            colContactState <- state,
            colMessageRef <- msgID // track latest contact message for timestamp
        ))
        /* TODO: add recps to contact
         // TODO: move this to all message types
         if pms {
         try self.insertPrivateRecps(rxID: rxID, recps: c.recps)
         }
         */
    }
    
    private func checkAndExecuteDCR(msgID: Int64, msg: KeyValue) throws {
        guard self.openDB != nil else {
            throw ViewDatabaseError.notOpen
        }

        guard let dcr = msg.value.content.dropContentRequest else {
            throw ViewDatabaseError.unhandledContentType(msg.value.content.type)
        }

        var claimedMsg: KeyValue? = nil
        do {
            claimedMsg = try self.get(key: dcr.hash)
        } catch ViewDatabaseError.unknownMessage(_) {
            return // not stored in view
        }

        guard let targetMsg = claimedMsg else {
            // we ignore the unknownMessage error above
            // all other cases should throw directly
            throw GoBotError.unexpectedFault("dcr handling error: should have thrown already")
        }

        guard targetMsg.value.author == msg.value.author else {
            return // ignore invalid
        }

        guard targetMsg.value.sequence == dcr.sequence else {
            return // ignore invalid
        }

        try self.deleteNoTransact(message: dcr.hash)
    }
    
    private func fillPub(msgID: Int64, msg: KeyValue) throws {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }

        guard let p = msg.value.content.pub else {
            Log.info("[viewdb/fill] broken pub message: \(msg.key)")
            return
        }

        try db.run(self.pubs.insert(or: .replace,
                                    colMessageRef <- msgID,
                                    colHost <- p.address.host,
                                    colPort <- Int(p.address.port),
                                    colKey <- p.address.key))
    }
    
    private func fillPost(msgID: Int64, msg: KeyValue, pms: Bool) throws {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }
        guard let p = msg.value.content.post else {
            Log.info("[viewdb/fill] broken post message: \(msg.key)")
            return
        }
        
        if pms { // TODO: move this to all message types
            try self.insertPrivateRecps(msgID: msgID, recps: p.recps)
        }
        
        try db.run(self.posts.insert(
            colMessageRef <- msgID,
            colIsRoot <- p.root == nil,
            colText <- p.text
        ))
        
        try self.insertBranches(msgID: msgID, root: p.root, branches: p.branch)
        
        if let m = p.mentions {
            try self.insertMentions(msgID: msgID, mentions: m)
        }
        
        if let b = p.mentions?.asBlobs() {
            try self.insertBlobs(msgID: msgID, blobs: b)
        }

        if let htags = p.mentions?.asHashtags() {
            try self.insertHashtags(msgID: msgID, tags: htags)
        }
    }
    
    private func fillVote(msgID: Int64, msg: KeyValue, pms: Bool) throws {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }
        
        guard let v = msg.value.content.vote else {
            Log.info("[viewdb/fill] broken vote message: \(msg.key)")
            return
        }
        
        if v.vote.link.id == .unsupported {
            // hack1: better discard such votes
            return
        }
        
        if pms { // TODO: move this to all message types
            try self.insertPrivateRecps(msgID: msgID, recps: v.recps)
        }
        
        try db.run(self.votes.insert(
            colMessageRef <- msgID,
            colLinkID <- try self.msgID(of: v.vote.link, make: true),
            colExpression <- v.vote.expression ?? "",
            colValue <- v.vote.value
        ))
        
        try self.insertBranches(msgID: msgID, root: v.root, branches: v.branch)
    }
    
    private func fillReportIfNeeded(msgID: Int64, msg: KeyValue, pms: Bool) throws -> [Report] {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }
        
        let createdAt = Date().timeIntervalSince1970 * 1000
        
        switch msg.value.content.type { // insert individual message types
        case .contact:
            guard let c = msg.value.content.contact else {
                return []
            }
            guard c.isFollowing else {
                // Just report on follows
                return []
            }
            let author = try? self.authorID(of: c.contact, make: false)
            if let followedAuthor = author {
                try db.run(self.reports.insert(
                    colMessageRef <- msgID,
                    colAuthorID <- followedAuthor,
                    colReportType <- ReportType.feedFollowed.rawValue,
                    colCreatedAt <- createdAt
                ))
                let report = Report(authorIdentity: c.contact,
                                    messageIdentifier: msg.key,
                                    reportType: .feedFollowed,
                                    createdAt: Date(timeIntervalSince1970: createdAt / 1000),
                                    keyValue: msg)
                return [report]
            }
        case .post:
            guard let p = msg.value.content.post else {
                return []
            }
            var reportsIdentities = [Identity]()
            var reports = [Report]()
            
            if let identifier = p.root {
                let msgId = try self.msgID(of: identifier, make: false)
                let repliedMsg = try db.pluck(self.msgs.filter(colMessageID == msgId))
                if let repliedMsg = repliedMsg {
                    let repliedAuthor = repliedMsg[colAuthorID]
                    let repliedIdentity = try self.author(from: repliedAuthor)
                    
                    if repliedIdentity != msg.value.author {
                        try db.run(self.reports.insert(
                            colMessageRef <- msgID,
                            colAuthorID <- repliedAuthor,
                            colReportType <- ReportType.postReplied.rawValue,
                            colCreatedAt <- createdAt
                        ))
                        
                        
                        let report = Report(authorIdentity: repliedIdentity,
                                            messageIdentifier: msg.key,
                                            reportType: .postReplied,
                                            createdAt: Date(timeIntervalSince1970: createdAt / 1000),
                                            keyValue: msg)
                        reports.append(report)
                        reportsIdentities.append(repliedIdentity)
                    }
                    
                    let otherReplies = try self.getRepliesTo(thread: identifier)
                    for reply in otherReplies {
                        let replyAuthorIdentity = reply.value.author
                        if !reportsIdentities.contains(replyAuthorIdentity), let replyAuthorID = try? self.authorID(of: replyAuthorIdentity), replyAuthorIdentity != msg.value.author {
                            try db.run(self.reports.insert(
                                colMessageRef <- msgID,
                                colAuthorID <- replyAuthorID,
                                colReportType <- ReportType.postReplied.rawValue,
                                colCreatedAt <- createdAt
                            ))
                            
                            let report = Report(authorIdentity: replyAuthorIdentity,
                                                messageIdentifier: msg.key,
                                                reportType: .postReplied,
                                                createdAt: Date(timeIntervalSince1970: createdAt / 1000),
                                                keyValue: msg)
                            reports.append(report)
                            reportsIdentities.append(replyAuthorIdentity)
                        }
                    }
                }
            }
            if let mentions = p.mentions {
                for mention in mentions {
                    let identifier = mention.link
                    switch identifier.sigil {
                    case .feed:
                        let author = try? self.authorID(of: identifier, make: false)
                        if let mentionedAuthor = author, !reportsIdentities.contains(identifier) {
                            try db.run(self.reports.insert(
                                colMessageRef <- msgID,
                                colAuthorID <- mentionedAuthor,
                                colReportType <- ReportType.feedMentioned.rawValue,
                                colCreatedAt <- createdAt
                            ))
                            
                            let report = Report(authorIdentity: identifier,
                                                messageIdentifier: msg.key,
                                                reportType: .feedMentioned,
                                                createdAt: Date(timeIntervalSince1970: createdAt / 1000),
                                                keyValue: msg)
                            reports.append(report)
                            reportsIdentities.append(identifier)
                        }
                    case .message, .blob:
                        continue
                    case .unsupported:
                        continue
                    }
                }
            }
            return reports
        case .vote:
            guard let v = msg.value.content.vote, v.vote.link.id != .unsupported else {
                return []
            }
            guard v.vote.value > 0 else {
                // Just report on likes, not dislikes
                return []
            }
            let identifier = v.vote.link
            switch identifier.sigil {
            case .message:
                let msgAuthor = try? self.getAuthorOf(key: identifier)
                if let likedMsgAuthor = msgAuthor {
                    try db.run(self.reports.insert(
                        colMessageRef <- msgID,
                        colAuthorID <- likedMsgAuthor,
                        colReportType <- ReportType.messageLiked.rawValue,
                        colCreatedAt <- createdAt
                    ))
                    let likedMsgIdentity = try self.author(from: likedMsgAuthor)
                    let report = Report(authorIdentity: likedMsgIdentity,
                                        messageIdentifier: msg.key,
                                        reportType: .messageLiked,
                                        createdAt: Date(timeIntervalSince1970: createdAt / 1000),
                                        keyValue: msg)
                    return [report]
                }
            case .feed, .blob:
                break
            case .unsupported:
                break
            }
        case .address:
             break
        case .about:
            break
        case .dropContentRequest:
            break
        case .pub:
            break
        case .unknown:
            break
        case .unsupported:
            break
        }
        return []
    }
    
    private func isOldMessage(msg: KeyValue) -> Bool {
        let now = Date(timeIntervalSinceNow: 0)
        let claimed = Date(timeIntervalSince1970: msg.value.timestamp/1000)
        let since = claimed.timeIntervalSince(now)
        return since < self.temporaryMessageExpireDate
    }
    
    func fillMessages(msgs: [KeyValue], pms: Bool = false) throws {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }

        #if SSB_MSGDEBUG
        // google claimed this is the tool to use to measure block execution time
        let start = CFAbsoluteTimeGetCurrent()
        // get an idea how many unsupported messages there are
        var unsupported: [String:Int] = [:]
        #endif
        
        var reports = [Report]()
        var skipped: UInt = 0
        try db.transaction { // also batches writes! helps a lot with perf
            var lastRxSeq: Int64 = -1
            
            let loopStart = Date().timeIntervalSince1970*1000
            let msgCount = msgs.count
            for (msgIndex, msg) in msgs.enumerated() {
                if let msgRxSeq = msg.receivedSeq {
                    lastRxSeq = msgRxSeq
                } else {
                    if !pms {
                        throw GoBotError.unexpectedFault("ViewDB: no receive sequence number on message")
                    }
                }
                
                /* This is the don't put older than 6 months in the db. */
                if isOldMessage(msg: msg) && (msg.value.content.type != .contact && msg.value.content.type != .about)  {
                    // TODO: might need to mark viewdb if all messags are skipped... current bypass: just incease the receive batch size (to 15k)
                    skipped += 1
                    print("Skipped(\(msg.value.content.type) \(msg.key)%)")
                    Analytics.shared.track(event: .did,
                               element: .bot,
                               name: AnalyticsEnums.Name.sync.rawValue,
                               params: ["Skipped": msg.key, "Reason": "Old Message"])
                    continue
                }
                
                
                if !pms && !msg.value.content.isValid {
                    // cant ignore PMs right now. they need to be there to be replaced with unboxed content.
                    #if SSB_MSGDEBUG
                    let cnt = (unsupported[msg.value.content.typeString] ?? 0) + 1
                    unsupported[msg.value.content.typeString] = cnt
                    #endif
                    skipped += 1
                    continue
                }

                /* don't hammer progress with every message
                if msgIndex%100 == 0 {
                    let done = Float64(msgIndex)/Float64(msgCount)
                    let prog = Notification.didUpdateDatabaseProgress(perc: done,
                                                                      status: "Processing new messages")
                    NotificationCenter.default.post(prog)
                }*/

                // make sure we dont have messages from the future
                // and force them to the _received_ timestamp so that they are not pinned to the top of the views
                var claimed = msg.value.timestamp
                if claimed > loopStart {
                    claimed = msg.timestamp
                }

                // can only insert PMs when the unencrypted was inserted before
                let msgKeyID = try self.msgID(of: msg.key, make: !pms)
                let authorID = try self.authorID(of: msg.value.author, make: true)
                
                // insert core message
                if pms {
                    let pm = self.msgs
                        .filter(colMessageID == msgKeyID)
                        .filter(colAuthorID == authorID)
                        .filter(colSequence == msg.value.sequence)
                    try db.run(pm.update(
                        colDecrypted <- true,
                        colMsgType <- msg.value.content.type.rawValue,
                        colReceivedAt <- msg.timestamp,
                        colClaimedAt <- claimed
                    ))
                } else {
                    do {
                        try db.run(self.msgs.insert(
                            colRXseq <- lastRxSeq,
                            colMessageID <- msgKeyID,
                            colAuthorID <- authorID,
                            colSequence <- msg.value.sequence,
                            colMsgType <- msg.value.content.type.rawValue,
                            colReceivedAt <- msg.timestamp,
                            colClaimedAt <- claimed
                        ))
                    } catch Result.error(let errMsg, let errCode, _) {
                        // this is _just_ hear because of a fetch-duplication bug in go-ssb
                        // the constraints on the table are for uniquness:
                        // 1) message key/id
                        // 2) (author,sequence no)
                        // while (1) always means duplicate message (2) can also mean fork
                        // the problem is, SQLITE can throw (1) or (2) and we cant keep them apart here...
                        if errCode == SQLITE_CONSTRAINT {
                            continue // ignore this message and go to the next
                        }
                        throw GoBotError.unexpectedFault("ViewDB/INSERT message error \(errCode): \(errMsg)")
                    } catch {
                        throw error
                    }
                }
          
                do { // identifies which message failed
                    switch msg.value.content.type { // insert individual message types

                    case .address:
                         try self.fillAddress(msgID: msgKeyID, msg: msg)
                        
                    case .about:
                        try self.fillAbout(msgID: msgKeyID, msg: msg)
                        
                    case .contact:
                        try self.fillContact(msgID: msgKeyID, msg: msg)

                    case .dropContentRequest:
                        try self.checkAndExecuteDCR(msgID: msgKeyID, msg: msg)

                    case .pub:
                         try self.fillPub(msgID: msgKeyID, msg: msg)

                    case .post:
                        try self.fillPost(msgID: msgKeyID, msg: msg, pms: pms)
                
                    case .vote:
                        try self.fillVote(msgID: msgKeyID, msg: msg, pms: pms)

                    case .unknown: // ignore encrypted
                        continue

                    case .unsupported:
                        // counted above
                        continue
                    }
                } catch {
                    throw GoBotError.duringProcessing("fillMessages threw on msg(\(msg.key)", error)
                }
                
                do {
                    let reportsFilled = try self.fillReportIfNeeded(msgID: msgKeyID, msg: msg, pms: pms)
                    reports.append(contentsOf: reportsFilled)
                } catch {
                    // Don't throw an error here, because we can live without a report
                    // Just send it to the Crash Reporting service
                    CrashReporting.shared.reportIfNeeded(error: error)
                }
            } // for msgs
            
            reports.forEach { report in
                NotificationCenter.default.post(name: Notification.Name("didCreateReport"),
                                                object: report.authorIdentity,
                                                userInfo: ["report": report])
            }
            
            // if we skipped all messages because they are unsupported,
            // update %fakemsg to that sequence so that we don't iterate over them again
            if skipped > 0 && skipped == msgs.count && lastRxSeq > 0 {
                try self.updateFakeMsg(seq: lastRxSeq)
            }
        } // transact

        // debug statistics about unhandled message types
        #if SSB_MSGDEBUG
        let done = CFAbsoluteTimeGetCurrent()
        print("inserted \(msgs.count) in \(done)s")
         
        if unsupported.count > 0 { // TODO: Log.debug?
            for (tipe, cnt) in unsupported {
                if unsupported.keys.count < 10 {
                    Log.info("\(tipe): \(cnt)")
                }
            }
            print("unsupported types encountered: \(total) (\(total*100/msgs.count)%)")
        }
        #endif
        
        
         let params = [
             "inserted": msgs.count

         ]

        
        Analytics.shared.track(event: .did,
                         element: .bot,
                         name: AnalyticsEnums.Name.db_update.rawValue,
                         params: params)
        
        
        if skipped > 0 {
            print("skipped \(skipped) messages")
        }
    }
    
    // MARK: utilities

    // TODO: RAM cache for these msgRef:IntID maps?
    private func msgID(of key: MessageIdentifier, make: Bool = false) throws -> Int64 {
        guard let db = self.openDB else { throw ViewDatabaseError.notOpen }

        if let msgKeysRow = try db.pluck(self.msgKeys.filter(colKey == key)) {
            return msgKeysRow[colID]
        }

        guard make else { throw ViewDatabaseError.unknownMessage(key) }

        return try db.run(self.msgKeys.insert(
            colKey <- key,
            colHashedKey <- key.sha256hash
        ))
    }

    private func msgID(of msg: KeyValue, make: Bool = false) throws -> Int64 {
        guard let db = self.openDB else { throw ViewDatabaseError.notOpen }

        if let msgKeysRow = try db.pluck(self.msgKeys.filter(colKey == msg.key)) {
            return msgKeysRow[colID]
        }

        guard make else { throw ViewDatabaseError.unknownMessage(msg.key) }

        guard let hk = msg.hashedKey else { throw GoBotError.unexpectedFault("missing hashed key on fresh message") }
        return try db.run(self.msgKeys.insert(
            colKey <- msg.key,
            colHashedKey <- hk
        ))
    }

    private func msgKey(id: Int64) throws -> MessageIdentifier {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }
        
        var msgKey: MessageIdentifier
        if let msgKeysRow = try db.pluck(self.msgKeys.filter(colID == id)) {
            msgKey = msgKeysRow[colKey]
        } else {
            throw ViewDatabaseError.unknownReferenceID(id)
        }
        return msgKey
    }
    
    private func authorID(of author: Identity, make: Bool = false) throws -> Int64 {
        guard let db = self.openDB else { throw ViewDatabaseError.notOpen }

        if let authorRow = try db.pluck(self.authors.filter(colAuthor == author)) {
            return authorRow[colID]
        }

        guard make else { throw ViewDatabaseError.unknownAuthor(author) }

        return try db.run(self.authors.insert(
            colAuthor <- author,
            colHashedKey <- author.sha256hash
        ))
    }
    
    
    private func author(from id: Int64) throws -> Identity {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }
        
        var authorKey: Identity
        if let msgKeysRow = try db.pluck(self.authors.filter(colID == id)) {
            authorKey = msgKeysRow[colAuthor]
        } else {
            throw ViewDatabaseError.unknownReferenceID(id)
        }
        return authorKey
    }
    
    // checks if pubKey is a known local thing, otherwise returns nil
    func identityFromPublicKey(pubKey: String) -> Identity? {
        guard let _ = self.openDB else {
            let error = ViewDatabaseError.notOpen
            Log.optional(error)
            CrashReporting.shared.reportIfNeeded(error: error)
            return nil
        }
        let knownFormats = ["ed25519", "ggfeed-v1"]
        for format in knownFormats {
            let ggFormatGuess = "@\(pubKey).\(format)"
            let aid = try? self.authorID(of: ggFormatGuess, make: false)
            if aid != 0 {
                return ggFormatGuess
            }
        }
        return nil
    }

    // MARK: insert helper
    
    private func insertPrivateRecps(msgID: Int64, recps: [RecipientElement]?) throws {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }
        guard let recps = recps else {
            // some early messages might not have recps
            Log.unexpected(.missingValue, "[viewdb] warning: no recps in private message (msgID:\(msgID))")
            return
        }
        for recp in getRecipientIdentities(recps: recps) {
            let recpID = try self.authorID(of: recp, make: true)
            try db.run(self.privateRecps.insert(
                colMessageRef <- msgID,
                colContactID <- recpID
            ))
        }
    }
   
    private func insertBranches(msgID: Int64, root: MessageIdentifier?, branches: [MessageIdentifier]?) throws {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }

        // with root but no branch is a malformed message and should be discarded earlier!
        guard let r = root else { return }
        guard let br = branches else { return }
        
        if r.sigil != .message {
            return
        }

        let tangleID = try db.run(self.tangles.insert(
            colMessageRef <- msgID,
            colRoot <- try self.msgID(of: r, make: true)
        ))
    
        for branch in br {
            try db.run(self.branches.insert(
                colTangleID <- tangleID,
                colBranch <-  try self.msgID(of: branch, make: true)
            ))
        }
    }
    
    private func insertMentions(msgID: Int64, mentions: [Mention]) throws {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }

        let notBlobs = mentions.filter { return !$0.link.isBlob }
        for m in notBlobs {
            if !m.link.isValidIdentifier {
                continue
            }
            // TOOD: name might be a channel!
            switch m.link.sigil {
            case .message:
                try db.run(self.mentions_msg.insert(
                    colMessageRef <- msgID,
                    colLinkID <-  try self.msgID(of: m.link, make: true)
                ))
            case .feed:
                try db.run(self.mentions_feed.insert(
                    colMessageRef <- msgID,
                    colFeedID <-  try self.authorID(of: m.link, make: true),
                    colName <- m.name
                ))
            default:
                continue
            }
        }
    }
    
    private func loadMentions(for msgID: Int64) throws -> [Mention] {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }
        
        // load mentions for this message
        let feedQry = self.mentions_feed.where(colMessageRef == msgID)
        let feedMentions: [Mention] = try db.prepare(feedQry).map {
            row in
            
            let feedID = try row.get(colFeedID)
            let feed = try self.author(from: feedID)
            
            return Mention(
                link: feed,
                name: try row.get(colName) ?? ""
            )
        }
        
        let msgMentionQry = self.mentions_msg.where(colMessageRef == msgID)
        let msgMentions: [Mention] = try db.prepare(msgMentionQry).map {
            row in
            
            let linkID = try row.get(colLinkID)
            return Mention(
                link: try self.msgKey(id: linkID),
                name: ""
            )
        }
        /*
        // TODO: We don't =populate mentions_images... so why are we looking it up?
        let imgMentionQry = self.mentions_image
            .where(colMessageRef == msgID)
            .where(colImage != "")
        let imgMentions: [Mention] = try db.prepare(imgMentionQry).map {
            row in
            
            let img = try row.get(colImage)
            
            return Mention(
                link: img!, // illegal insert
                name: try row.get(colName) ?? ""
            )
        }
        */
        
        return feedMentions + msgMentions
    }
    
    private func insertBlobs(msgID: Int64, blobs: [Blob]) throws {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }
        for b in blobs {
            if !b.identifier.isValidIdentifier {
                continue
            }
            try db.run(self.post_blobs.insert(
                colMessageRef <- msgID,
                colIdentifier <- b.identifier,
                colName <- b.name,
                colMetaHeight <- b.metadata?.dimensions?.height,
                colMetaWidth <- b.metadata?.dimensions?.width,
                colMetaBytes <- b.metadata?.numberOfBytes,
                colMetaMimeType <- b.metadata?.mimeType,
                colMetaAverageColorRGB <- b.metadata?.averageColorRGB
            ))
        }
    }

    private func loadBlobs(for msgID: Int64) throws -> [Blob] {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }
        
        //let supportedMimeTypes = [MIMEType.jpeg, MIMEType.png]
        
        let qry = self.post_blobs.where(colMessageRef == msgID)
            .filter(colMetaMimeType == "image/jpeg" || colMetaMimeType == "image/png" )
        
        let blobs: [Blob] = try db.prepare(qry).map {
            row in
            let img_hash = try row.get(colIdentifier)

            var dim: Blob.Metadata.Dimensions?
            if let w = try row.get(colMetaWidth) {
                if let h = try row.get(colMetaHeight) {
                    dim = Blob.Metadata.Dimensions(width: w, height: h)
                }
            }

            let meta = Blob.Metadata(
                averageColorRGB: try row.get(colMetaAverageColorRGB),
                dimensions: dim,
                mimeType: try row.get(colMetaMimeType),
                numberOfBytes: try row.get(colMetaBytes))

            return Blob(
                identifier: img_hash,
                name: try? row.get(colName),
                metadata: meta
            )
        }
        return blobs
    }
    
    private func insertHashtags(msgID: Int64, tags: [Hashtag]) throws {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }
        for h in tags {
            let chanID = try self.channelID(from: h.name, make: true)
            try db.run(self.channelAssigned.insert(
                colMessageRef <- msgID,
                colChanRef <- chanID
            ))
        }
    }
} // end class
