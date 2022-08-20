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
import Logger
import Analytics
import CrashReporting
import SQLite3

// schema migration handling
extension Connection {
    public var userVersion: Int32 {
        get { Int32(try! scalar("PRAGMA user_version;") as! Int64) }
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
    case banList = "ban_list"
    case blogs
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
    case rooms
    case readMessages = "read_messages"
}

class ViewDatabase {
    var currentPath: String { get { self.dbPath } }
    private var dbPath: String = "/tmp/unset"
    private var openDB: Connection?

    // TODO: use this to trigger fill on update and wipe previous versions
    // https://app.asana.com/0/914798787098068/1151842364054322/f
    static let schemaVersion: UInt = 20

    // should be changed on login/logout
    private var currentUserID: Int64 = -1
    private(set) var currentUser: Identity?

    // skip messages older than this (6 months)
    // this should be removed once the database was refactored
    private var temporaryMessageExpireDate: Double = -60 * 60 * 24 * 30 * 6

    // All messages in the network should be as read if true. This is to prevent a user that runs into
    // the migration that creates the read_messages table to have all the messages as unread. It cannot be
    // done during migration as we need to know the user id
    var needsToSetAllMessagesAsRead = false
    
    // MARK: Tables and fields
    let colID = Expression<Int64>("id")
    
    let authors = Table(ViewDatabaseTableNames.authors.rawValue)
    let colAuthor = Expression<Identity>("author")
    let colBanned = Expression<Bool>("banned")
    
    let msgKeys = Table(ViewDatabaseTableNames.messagekeys.rawValue)
    let colKey = Expression<MessageIdentifier>("key")
    let colHashedKey = Expression<String>("hashed")
    
    let msgs = Table(ViewDatabaseTableNames.messages.rawValue)
    let colHidden = Expression<Bool>("hidden")
    let colRXseq = Expression<Int64>("rx_seq")
    let colMessageID = Expression<Int64>("msg_id")
    let colAuthorID = Expression<Int64>("author_id")
    let colSequence = Expression<Int>("sequence")
    let colMsgType = Expression<String>("type")
    // received time in milliseconds since the unix epoch
    let colReceivedAt = Expression<Double>("received_at")
    let colWrittenAt = Expression<Double>("written_at")
    let colClaimedAt = Expression<Double>("claimed_at")
    let colDecrypted = Expression<Bool>("is_decrypted")
    /// A flag that is true if this message is not from a real feed. The `WelcomeService` inserts "fake" messages
    /// into SQLite to help with onboarding.
    let colOffChain = Expression<Bool>("off_chain")
    
    let colMessageRef = Expression<Int64>("msg_ref")

    let abouts = Table(ViewDatabaseTableNames.abouts.rawValue)
    let colAboutID = Expression<Int64>("about_id")
    let colName = Expression<String?>("name")
    let colImage = Expression<BlobIdentifier?>("image")
    let colDescr = Expression<String?>("description")
    let colPublicWebHosting = Expression<Bool?>("publicWebHosting")
    
    let banList = Table(ViewDatabaseTableNames.banList.rawValue)
    let colHash = Expression<String>("hash")
    // colID
    let colIDType = Expression<Int>("type")
    
    let contacts = Table(ViewDatabaseTableNames.contacts.rawValue)
    // colAuthorID
    let colContactID = Expression<Int64>("contact_id")
    let colContactState = Expression<Int>("state")
    
    let posts = Table(ViewDatabaseTableNames.posts.rawValue)
    let colText = Expression<String>("text")
    let colIsRoot = Expression<Bool>("is_root")
    
    let post_blobs = Table(ViewDatabaseTableNames.postBlobs.rawValue)
    // msg_ref
    let colIdentifier = Expression<String>("identifier") // TODO: blobHash:ID
    // colName
    let colMetaBytes = Expression<Int?>("meta_bytes")
    let colMetaWidth = Expression<Int?>("meta_widht")
    let colMetaHeight = Expression<Int?>("meta_height")
    let colMetaMimeType = Expression<String?>("meta_mime_type")
    let colMetaAverageColorRGB = Expression<Int?>("meta_average_color_rgb")
    
    // blogs
    let blogs = Table(ViewDatabaseTableNames.blogs.rawValue)
    let colSummary = Expression<String>("summary")
    let colTitle = Expression<String>("title")
    let colBlog = Expression<String>("blog")
    
    let mentions_feed = Table(ViewDatabaseTableNames.mentionsFeed.rawValue)
    // msg_ref
    let colFeedID = Expression<Int64>("feed_id")
    
    let mentions_msg = Table(ViewDatabaseTableNames.mentionsMsg.rawValue)
    // msg_ref
    // link_id
    
    let mentions_image = Table(ViewDatabaseTableNames.mentionsImage.rawValue)
    // msg_ref
    // link_id
    
    let votes = Table(ViewDatabaseTableNames.votes.rawValue)
    let colLinkID = Expression<Int64>("link_id")
    let colValue = Expression<Int>("value")
    let colExpression = Expression<String?>("expression")

    let channels = Table(ViewDatabaseTableNames.channels.rawValue)
    // id
    // name
    let colLegacy = Expression<Bool>("legacy")
    
    // what messages are in a channel?
    let channelAssigned = Table(ViewDatabaseTableNames.channelsAssigned.rawValue)
    // msg_ref
    let colChanRef = Expression<Int64>("chan_ref")

    let tangles = Table(ViewDatabaseTableNames.tangles.rawValue)
    let colRoot = Expression<Int64>("root")
    
    let branches = Table(ViewDatabaseTableNames.branches.rawValue)
    let colTangleID = Expression<Int64>("tangle_id")
    let colBranch = Expression<Int64>("branch")
    
    let privateRecps = Table(ViewDatabaseTableNames.privateRecps.rawValue)
    // msg_ref
    // contact_id
    
    let addresses: Table = Table(ViewDatabaseTableNames.addresses.rawValue)
    let colAddressID = Expression<Int64>("address_id")
    // colAboutID
    let colAddress = Expression<String>("address")
    let colWorkedLast = Expression<Date?>("worked_last")
    let colLastErr = Expression<String>("last_err")
    let colUse = Expression<Bool>("use")
    let colRedeemed = Expression<Double?>("redeemed")
    
    // Reports
    let reports = Table(ViewDatabaseTableNames.reports.rawValue)
    // colMessageRef
    // colAuthorID
    let colReportType = Expression<String>("type")
    let colCreatedAt = Expression<Double>("created_at")
    
    // Pubs
    let pubs = Table(ViewDatabaseTableNames.pubs.rawValue)
    // colMessageRef
    let colHost = Expression<String>("host")
    let colPort = Expression<Int>("port")
    // colKey
    
    // Rooms
    let rooms = Table(ViewDatabaseTableNames.rooms.rawValue)
    
    // Search
    private let postSearch = VirtualTable("post_search")

    // Read messages
    let readMessages = Table(ViewDatabaseTableNames.readMessages.rawValue)
    // colMessageID
    // colAuthorID
    let colIsRead = Expression<Bool>("is_read")

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
            tries < 4
        }
        
        self.openDB = db
        try db.execute("PRAGMA journal_mode = WAL;")
        try db.execute("PRAGMA synchronous = NORMAL;") // Full is best for read performance
        
        // db.trace { print("\tSQL: \($0)") } // print all the statements
        
        try checkAndRunMigrations(on: db)
        
        self.currentUser = user
        self.currentUserID = try self.authorID(of: user, make: true)

        try setAllMessagesAsReadIfNeeded()
    }
    
    /// Runs any db migrations that haven't been run yet.
    private func checkAndRunMigrations(on db: Connection) throws {
        try db.transaction {
            // Previous migrations dropped in 1.2.0 since we deleted and recreated the SQLite db.
            if db.userVersion == 0 {
                let schemaV1url = Bundle.current.url(forResource: "ViewDatabaseSchema.sql", withExtension: nil)!
                try db.execute(String(contentsOf: schemaV1url))
                db.userVersion = 9
            }
            if db.userVersion == 9 {
                try db.execute("ALTER TABLE `blocked_content` RENAME TO `banned_content`;")
                db.userVersion = 10
            }
            if db.userVersion == 10 {
                // Run this as a migration since we haven't ever run it before.
                try db.execute("PRAGMA optimize;")
                db.userVersion = 11
            }
            if db.userVersion == 11 {
                try db.run(
                    postSearch.create(
                        .FTS4(
                            FTS4Config()
                                .column(colMessageRef)
                                .column(colText)
                        )
                    )
                )
                let posts = try db.prepare(posts)
                for post in posts {
                    try db.run(
                        postSearch.insert(
                            colMessageRef <- post[colMessageRef],
                            colText <- post[colText]
                        )
                    )
                }
                db.userVersion = 12
            }
            if db.userVersion == 12 {
                try db.execute("ALTER TABLE messages ADD off_chain INTEGER NOT NULL DEFAULT (0);")
                db.userVersion = 13
            }
            if db.userVersion == 13 {
                // We created some indexes here but reverted them in migration 15->16
                db.userVersion = 14
            }
            if db.userVersion == 14 {
                try db.execute(
                    """
                    CREATE TABLE
                        read_messages (
                            author_id BIGINT null,
                            msg_id BIGINT null,
                            is_read BOOLEAN not null default true,
                            PRIMARY KEY (author_id, msg_id)
                        );
                    """
                )
                db.userVersion = 15
                needsToSetAllMessagesAsRead = true
            }
            if db.userVersion == 15 {
                try db.execute(
                    """
                        DROP INDEX IF EXISTS channel_assignments_idx_0039db;
                        DROP INDEX IF EXISTS channel_assignments_idx_e349b0cd;
                        DROP INDEX IF EXISTS pubs_index;
                        DROP INDEX IF EXISTS tangles_roots_and_msg_refs;
                        DROP INDEX IF EXISTS posts_root_mesgrefs;
                        DROP INDEX IF EXISTS mention_feed_author_refs;
                        DROP INDEX IF EXISTS contacts_msg_ref;
                        DROP INDEX IF EXISTS contacts_state_and_author;
                        DROP INDEX IF EXISTS channel_assignments_msg_refs;
                        DROP INDEX IF EXISTS channel_assignments_chan_ref_and_msg_ref;
                        DROP INDEX IF EXISTS messages_idx_type_claimed_at;
                        DROP INDEX IF EXISTS messages_idx_author_received;
                        DROP INDEX IF EXISTS messages_idx_author_type_sequence;
                        DROP INDEX IF EXISTS messages_idx_is_decrypted_hidden_claimed_at;
                        DROP INDEX IF EXISTS messages_idx_type_is_decrypted_hidden_author;
                        DROP INDEX IF EXISTS messages_idx_type_is_decrypted_hidden_claimed_at;
                        DROP INDEX IF EXISTS messages_idx_is_decrypted_hidden_author_claimed_at;
                        DROP INDEX IF EXISTS reports_author_created_at;
                        DROP INDEX IF EXISTS reports_msg_ref;
                        DROP INDEX IF EXISTS reports_msg_ref_author;
                    """
                )
                db.userVersion = 16
            }
            if db.userVersion == 16 {
                try db.execute(
                    """
                    ALTER TABLE authors ADD banned INTEGER NOT NULL DEFAULT (0);
                    DROP TABLE banned_content;
                    CREATE TABLE
                        ban_list (
                            hash TEXT
                        );
                    CREATE INDEX ban_list_hash on ban_list (hash);
                    """
                )
                db.userVersion = 17
            }
            if db.userVersion == 17 {
                try db.execute(
                    """
                    CREATE TABLE rooms (
                        address TEXT UNIQUE NOT NULL
                    );
                    CREATE INDEX rooms_address on rooms (address);
                    """
                );
            }
            if db.userVersion == 18 {
                try db.execute(
                    """
                    CREATE TABLE
                        blogs (
                            msg_ref              integer not null,
                            is_root              boolean default false,
                            title                varchar(255),
                            summary              varchar(255),
                            blob                 varchar(255),
                            
                            PRIMARY KEY (msg_ref)
                        );
                    CREATE INDEX blogss_msgrefs on blogs (msg_ref);
                    CREATE INDEX blogss_roots on blogs (is_root);
                    """
                )
                db.userVersion = 19
            }
        }
    }

    /// Set all messages as read if needsToSetAllMessagesAsRead is on
    func setAllMessagesAsReadIfNeeded() throws {
        guard needsToSetAllMessagesAsRead else {
            return
        }
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }
        try db.execute(
            """
            INSERT OR REPLACE INTO read_messages
            SELECT \(currentUserID), msg_id, true FROM messages;
            """
        )
    }
    
    // this open() is only needed for testing to extend the max age for the fixures... :'(
    #if DEBUG
    func open(path: String, user: Identity, maxAge: Double) throws {
        try self.open(path: path, user: user)
        self.temporaryMessageExpireDate = maxAge
    }
    #endif
    
    func isOpen() -> Bool {
        self.openDB != nil
    }
    
    func close() {
        if let db = openDB {
            do {
                try db.execute("PRAGMA analysis_limit = 400;")
                try db.execute("PRAGMA optimize;")
                // this event is mostly so that I can make sure this works reliably in production and the app
                // isn't being terminated before it's done.
                Analytics.shared.trackBotDidOptimizeSQLite()
                Log.info("Finished optimizing db")
            } catch {
                Log.optional(error)
                CrashReporting.shared.reportIfNeeded(error: error)
            }
        }
        self.openDB = nil
        self.currentUser = nil
        self.currentUserID = -1
    }
    
    func getOpenDB() -> Connection? {
        guard let db = self.openDB else { return nil }
        return db
    }
    
    // returns the number of rows for the respective tables
    func stats() throws -> [ViewDatabaseTableNames: Int] {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }
        
        return [
            .addresses: try db.scalar(self.addresses.count),
            .authors: try db.scalar(self.authors.count),
            .messages: try db.scalar(self.msgs.count),
            .abouts: try db.scalar(self.abouts.count),
            .contacts: try db.scalar(self.contacts.count),
            .privates: try db.scalar(self.msgs.filter(colDecrypted == true).count),
            .posts: try db.scalar(self.posts.count),
            .votes: try db.scalar(self.votes.count)
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
            case .messagekeys: cnt = Int(try self.largestSeqFromReceiveLog())
            case .abouts:   cnt = try db.scalar(self.abouts.count)
            case .contacts: cnt = try db.scalar(self.contacts.count)
            case .privates: cnt = try db.scalar(self.msgs.filter(colDecrypted == true).count)
            case .posts:    cnt = try db.scalar(self.posts.count)
            case .votes:    cnt = try db.scalar(self.votes.count)
            default: throw ViewDatabaseError.unknownTable(table)
        }
        return cnt
    }
    
    // helper to get some counts for pagination
    func statsForRootPosts(strategy: FeedStrategy) throws -> Int {
        guard let connection = self.openDB else {
            throw ViewDatabaseError.notOpen
        }
        return try strategy.countNumberOfKeys(connection: connection, userId: currentUserID)
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
    
    /// Finds the largest sequence number in the messages table.
    ///
    /// The returned sequence number is the index of a message in go-ssb's RootLog of all messages.
    func largestSeqFromReceiveLog() throws -> Int64 {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }
        
        let rxMaybe = Expression<Int64?>("rx_seq")
        if let rx = try db.scalar(msgs.select(rxMaybe.max)) {
            return rx
        }
        
        return -1
    }
    
    /// Finds the largest sequence number in the messages table, excluding posts that the user has published. This is
    /// useful for comparing messages in the `ViewDatabase` to those in go-ssb's log. The user's posts are synced
    /// immediately after publish so that's why we ignore them.
    ///
    /// The returned sequence number is the index of a message in go-ssb's RootLog of all messages.
    func largestSeqNotFromPublishedLog() throws -> Int64 {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }
        
        let rxMaybe = Expression<Int64?>("rx_seq")
        if let rx = try db.scalar(self.msgs.select(rxMaybe.max).where(msgs[colAuthorID] != currentUserID)) {
            return rx
        }
        
        return -1
    }
    
    /// Finds the largest sequence number of all the posts the logged-in user has published. The sequence number is the
    /// index of a message in go-ssb's RootLog of all messages.
    func largestSeqFromPublishedLog() throws -> Int64 {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }
        
        let rxMaybe = Expression<Int64?>("rx_seq")
        if let rx = try db.scalar(msgs.select(rxMaybe.max).where(msgs[colAuthorID] == currentUserID)) {
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
    
    /// Returns the date at which the newest row in the messages table was inserted. Useful for getting a rough idea of
    /// the last time the user synced with peers.
    func lastWrittenMessageDate() throws -> Date? {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }
        
        if let milliseconds = try db.scalar(msgs.select(colWrittenAt.max)) {
            return Date(milliseconds: milliseconds)
        } else {
            return nil
        }
    }
    
    func message(with id: MessageIdentifier) throws -> KeyValue {
        let msgId = try self.msgID(of: id, make: false)
        return try post(with: msgId)
    }
    
    // MARK: pubs & rooms

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
                redeemedDate = Date(timeIntervalSince1970: redeemedTimestamp / 1_000)
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
    
    func getJoinedPubs() throws -> [Pub] {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }

        let query = self.msgs
            .join(self.pubs, on: self.pubs[colMessageRef] == self.msgs[colMessageID])
            .where(self.msgs[colAuthorID] == currentUserID)
            .where(self.msgs[colMsgType] == "pub")
            .order(colSequence.desc)
        
        let pubs: [Pub] = try db.prepare(query).map { row in
            let host = try row.get(colHost)
            let port = try row.get(colPort)
            let key: Identifier = try row.get(colKey)
            
            return Pub(
                type: .pub,
                address: PubAddress(
                    key: key,
                    host: host,
                    port: UInt(port)
                )
            )
        }
        
        // Filter out duplicates
        var seenIDs = Set<PubAddress>()
        return pubs
            .filter { $0.address.key.isValidIdentifier }
            .filter { seenIDs.insert($0.address).inserted }
    }
    
    func getJoinedRooms() throws -> [Room] {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }

        return try db.prepare(rooms).map { row in
            guard let address = MultiserverAddress(string: row[colAddress]) else {
                throw ViewDatabaseError.invalidAddress(row[colAddress])
            }
            return Room(address: address)
        }
    }
    
    func insert(room: Room) throws {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }
        
        try db.run(rooms.insert(colAddress <- room.address.string))
    }
    
    func delete(room: Room) throws {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }
        
        try db.run(rooms.filter(colAddress == room.address.string).delete())
    }
    
    // MARK: moderation / delete
    
    /// Takes a list of hashes of banned content and applies it to the db. This function returns a list of newly banned
    /// authors and newly unbanned authors.
    func applyBanList(
        _ banList: [String]
    ) throws -> (bannedAuthors: [FeedIdentifier], unbannedAuthors: [FeedIdentifier]) {
        try updateBanTable(from: banList)
        let bannedAuthors = try authorsMatching(banList: banList)
        let unbannedAuthors = try bannedAuthorsNotIn(banList: banList)
        try ban(authors: bannedAuthors)
        try unban(authors: unbannedAuthors)
        try deleteMessagesMatching(banList: banList)
        
        return (bannedAuthors, unbannedAuthors)
    }
    
    /// Overwrites the banList table with the new banList
    private func updateBanTable(from banList: [String]) throws {
        guard let db = self.openDB else { throw ViewDatabaseError.notOpen }
        
        try db.run(self.banList.delete())
        for banHash in banList {
            try db.run(self.banList.insert(colHash <- banHash))
        }
    }
    
    /// Looks for feed IDs that match the hashes in the ban list ban list.
    private func authorsMatching(banList: [String]) throws -> [FeedIdentifier] {
        guard let db = self.openDB else { throw ViewDatabaseError.notOpen }
        
        return try db.prepare(authors.select(colAuthor).filter(banList.contains(colHashedKey))).map { $0[colAuthor] }
    }
    
    /// Finds authors that are marked banned in the db but not the given ban list.
    private func bannedAuthorsNotIn(banList: [String]) throws -> [FeedIdentifier] {
        guard let db = self.openDB else { throw ViewDatabaseError.notOpen }
        
        return try db.prepare(
            authors
                .select(colAuthor)
                .filter(colBanned == true)
                .filter(!banList.contains(colHashedKey))
        )
        .map { $0[colAuthor] }
    }

    /// Marks an author as banned. This is mostly so that we can tell if they are subsequently unbanned.
    private func ban(authors: [FeedIdentifier]) throws {
        guard let db = self.openDB else { throw ViewDatabaseError.notOpen }
        
        try db.run(
            self.authors
                .filter(authors.contains(colAuthor))
                .update(colBanned <- true)
        )
        
        let authorIDs = try db.prepare(self.authors.select(colID).filter(authors.contains(colAuthor))).map { $0[colID] }
        try deleteNoTransaction(allFrom: authorIDs)
    }
    
    /// Marks a previously banned author as not banned anymore.
    /// We keep track of when authors are unbanned so we can unblock them at the replication level.
    private func unban(authors: [FeedIdentifier]) throws {
        guard let db = self.openDB else { throw ViewDatabaseError.notOpen }
        
        try db.run(
            self.authors
                .filter(authors.contains(colAuthor))
                .update(colBanned <- false)
        )
    }
    
    /// Deletes messages matching the given ban list from the messages table and related tables.
    private func deleteMessagesMatching(banList: [String]) throws {
        guard let db = self.openDB else { throw ViewDatabaseError.notOpen }
        
        // look for banned IDs in msgs
        let matchingMsgs = try db.prepare(
            msgKeys
                .join(msgs, on: colID == msgs[colMessageID])
                .filter(banList.contains(colHashedKey))
        )

        for row in matchingMsgs {
            try delete(message: row[colKey])
        }
    }
    
    /// Returns true if the given message is on the ban list.
    func messageMatchesBanList(_ message: KeyValue) throws -> Bool {
        guard let db = self.openDB else { throw ViewDatabaseError.notOpen }
        return try db.scalar(banList.filter(colHash == message.key.sha256hash).exists)
    }
    
    /// Returns true if the author of the given message is on the ban list.
    func authorMatchesBanList(_ message: KeyValue) throws -> Bool {
        guard let db = self.openDB else { throw ViewDatabaseError.notOpen }
        return try db.scalar(banList.filter(colHash == message.value.author.sha256hash).exists)
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
            try self.deleteNoTransaction(allFrom: [authorID])
        }
    }

    private func deleteNoTransaction(allFrom authorIDs: [Int64]) throws {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }

        // all from abouts
        try db.run(self.abouts.filter(authorIDs.contains(colAuthorID)).delete())

        // all from contacts
        try db.run(self.contacts.filter(authorIDs.contains(colAuthorID)).delete())

        // all their messages
        let allMsgsQry = self.msgs
            .select(colMessageID, colRXseq)
            .filter(authorIDs.contains(colAuthorID))
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
            self.abouts,
        ]

        // convert rows to [Int64] for (msg_id IN [x1,...,xN]) below
        let msgIDs = try allMessages.map { row in
            try row.get(colMessageID)
        }
        
        for chunk in msgIDs.chunked(into: 500) {
            for table in messageTables {
                let query = table.filter(chunk.contains(colMessageRef)).delete()
                try db.run(query)
            }

            // delete reply branches
            // refactor idea: could rename 'branch' column to msgRef
            // then branches can be part of messageTables
            try db.run(self.branches.filter(chunk.contains(colBranch)).delete())

            // delete the base messages
            try db.run(self.msgs.filter(chunk.contains(colMessageID)).delete())
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
        // delete message from all specialized tables
        let messageTables = [
            self.posts,
            self.post_blobs,
            self.blogs,
            self.tangles,
            self.mentions_msg,
            self.mentions_feed,
            self.mentions_image,
            self.privateRecps,
            self.abouts,
        ]
        for t in messageTables {
            try db.run(t.filter(colMessageRef == msgID).delete())
        }
        try db.run(self.branches.filter(colBranch == msgID).delete())
        try db.run(self.msgs.filter(colMessageID == msgID).delete())
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
            About(about: id,
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
            .order(self.abouts[colName])
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
    
    func abouts(withNameLike queryString: String) throws -> [About] {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }
        
        let query = self.abouts
            .join(self.authors, on: colID == self.abouts[colAboutID])
            .order(self.abouts[colName])
            .where(colName.like("%\(queryString)%"))
        
        var abouts: [About] = []
        
        let aboutsQuery = try db.prepare(query)
        for about in aboutsQuery {
            let about = About(
                about: try about.get(colAuthor),
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
    
    /// Returns the number of followers and follows for a given identity
    func countNumberOfFollowersAndFollows(feed: Identity) throws -> SocialStats {
        guard let connection = self.openDB else {
            throw ViewDatabaseError.notOpen
        }

        // swiftlint:disable indentation_width
        let queryString = """
        SELECT SUM(CASE WHEN follow.author = ? THEN 1 ELSE 0 END) as followers_count,
               SUM(CASE WHEN follower.author = ? THEN 1 ELSE 0 END) as follows_count
        FROM contacts
        JOIN authors follower ON follower.id = contacts.author_id
        JOIN authors follow ON follow.id = contacts.contact_id
        WHERE contacts.state = 1;
        """
        // swiftlint:enable indentation_width

        let query = try connection.prepare(queryString)
        return try query.bind(feed, feed).prepareRowIterator().map { countsRow -> SocialStats in
            let followersCount = try countsRow.get(Expression<Int>("followers_count"))
            let followsCount = try countsRow.get(Expression<Int>("follows_count"))
            return SocialStats(numberOfFollowers: followersCount, numberOfFollows: followsCount)
        }.first ?? SocialStats(numberOfFollowers: 0, numberOfFollows: 0)
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
    func paginatedFeed(with feedStrategy: FeedStrategy) throws -> (PaginatedKeyValueDataProxy) {
        let src = try RecentViewKeyValueSource(with: self, feedStrategy: feedStrategy)
        return try PaginatedPrefetchDataProxy(with: src)
    }

    func paginated(feed: Identity) throws -> (PaginatedKeyValueDataProxy) {
        let src = try FeedKeyValueSource(with: self, feed: feed)
        return try PaginatedPrefetchDataProxy(with: src!)
    }

    // MARK: recent
    func recentPosts(strategy: FeedStrategy, limit: Int, offset: Int? = nil) throws -> KeyValues {
        return try strategy.fetchKeyValues(database: self, userId: currentUserID, limit: limit, offset: offset)
    }

    func numberOfRecentPosts(with strategy: FeedStrategy, since message: MessageIdentifier) throws -> Int {
        guard let connection = self.openDB else {
            throw ViewDatabaseError.notOpen
        }
        return try strategy.countNumberOfKeys(connection: connection, userId: currentUserID, since: message)
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
            .filter(colClaimedAt <= Date().millisecondsSince1970)

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
    
    /// Same as basicRecentPostsQuery but just selects columns in msgs tabl
    private func minimumRecentPostsQuery(limit: Int, wantPrivate: Bool, onlyRoots: Bool = true, offset: Int? = nil) -> Table {
        var qry = self.msgs
            .join(.leftOuter, self.abouts, on: self.abouts[colAboutID] == self.msgs[colAuthorID])
            .filter(colMsgType == "post")           // only posts (no votes or contact messages)
            .filter(colDecrypted == wantPrivate)
            .filter(colHidden == false)

        if let offset = offset {
            qry = qry.limit(limit, offset: offset)
        } else {
            qry = qry.limit(limit)
        }

        if onlyRoots {
            qry = qry.filter(colIsRoot == true)
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
    // table.filter(!(array.contains(id)))

    private func mapQueryToKeyValue(qry: Table, useNamespacedTables: Bool = false) throws -> [KeyValue] {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }

        return try db.prepare(qry).compactMap { row in
            return try KeyValue(
                row: row,
                database: self,
                useNamespacedTables: true,
                hasMentionColumns: false,
                hasReplies: false
            )
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

        let msgs: [KeyValue] = try db.prepare(qry).map { row in
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
                    blobs: try self.loadBlobs(for: msgID),
                    mentions: try self.loadMentions(for: msgID),
                    root: rootKey,
                    text: try row.get(colText)
                )
                
                c = Content(from: p)
                
            case ContentType.vote.rawValue:
                
                let lnkID = try row.get(colLinkID)
                let lnkKey = try self.msgKey(id: lnkID)
                let expression = try row.get(colExpression)
                
                let rootID = try row.get(colRoot)
                let rootKey = try self.msgKey(id: rootID)

                let cv = ContentVote(
                    link: lnkKey,
                    value: try row.get(colValue),
                    expression: expression,
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
            .order(colMessageID.desc)
            .limit(limit)
        
        return try self.mapQueryToKeyValue(qry: qry, useNamespacedTables: true)
    }

    // MARK: - Reports

    /// Returns the total number of unread reports
    func countNumberOfUnreadReports() throws -> Int {
        guard let connection = self.openDB else {
            throw ViewDatabaseError.notOpen
        }
        let queryString = """
            SELECT
                COUNT(*)
            FROM
                reports r
                LEFT JOIN read_messages rm ON r.msg_ref = rm.msg_id
                AND r.author_id = rm.author_id
            WHERE
                r.author_id = ?
                AND (
                    rm.is_read = false
                    OR rm.is_read IS NULL
                );
        """
        let query = try connection.prepare(queryString)
        if let count = try query.scalar(currentUserID) as? Int64 {
            return Int(truncatingIfNeeded: count)
        }
        return 0
    }

    /// Returns a boolean indicating if the report was already read by the user.
    /// - parameter message: The message associated to the wanted report
    ///
    /// It returns true/false either if it was read or not, nil if the message doesn't exist or a report for the
    /// message doesn't exist.
    func isMessageForReportRead(for message: MessageIdentifier) throws -> Bool? {
        guard let connection = self.openDB else {
            throw ViewDatabaseError.notOpen
        }
        let queryString = """
        SELECT
            read_messages.is_read AS is_read
        FROM
            reports
            INNER JOIN messagekeys ON (messagekeys.id = reports.msg_ref)
            LEFT OUTER JOIN read_messages ON (
                (read_messages.msg_id = messagekeys.id)
                AND (read_messages.author_id = reports.author_id)
            )
        WHERE
            reports.author_id = ?
            AND messagekeys.key = ?
        LIMIT
            1
        """
        guard let row = try connection.prepare(queryString, currentUserID, message).prepareRowIterator().next() else {
            return nil
        }
        let isRead = try? row.get(Expression<Bool?>("is_read"))
        return isRead ?? false
    }

    /// Returns a report associated to a given message.
    ///
    /// - parameter message: The message associated to the wanted report
    ///
    /// This function returns nil if the message doesn't have an associated report.
    func report(for message: MessageIdentifier) throws -> Report? {
        guard let connection = self.openDB else {
            throw ViewDatabaseError.notOpen
        }
        let queryString = """
        SELECT
            reports.type AS report_type,
            reports.created_at AS created_at,
            messages.*,
            posts.*,
            contacts.*,
            contact_author.author AS contact_identifier,
            votes.*,
            messagekeys.*,
            authors.*,
            abouts.*,
            tangles.*,
            read_messages.is_read AS is_read
        FROM
            reports
            INNER JOIN messages ON (messages.msg_id = reports.msg_ref)
            LEFT OUTER JOIN posts ON (posts.msg_ref = messages.msg_id)
            LEFT OUTER JOIN contacts ON (contacts.msg_ref = messages.msg_id)
            LEFT JOIN authors AS contact_author ON contact_author.id = contacts.contact_id
            LEFT OUTER JOIN votes ON (votes.msg_ref = messages.msg_id)
            INNER JOIN messagekeys ON (messagekeys.id = messages.msg_id)
            INNER JOIN authors ON (authors.id = messages.author_id)
            INNER JOIN abouts ON (abouts.about_id = messages.author_id)
            LEFT OUTER JOIN tangles ON (tangles.msg_ref = messages.msg_id)
            LEFT OUTER JOIN read_messages ON (
                (read_messages.msg_id = messages.msg_id) AND (read_messages.author_id = reports.author_id)
            )
        WHERE
            reports.author_id = ?
            AND messagekeys.key = ?
        LIMIT
            1
        """

        guard let row = try connection.prepare(queryString, currentUserID, message).prepareRowIterator().next() else {
            return nil
        }
        return try? buildReport(from: row)
    }

    /// Returns the list of reports associated to the logged in user
    ///
    /// - parameter limit: The maximum number of reports in the list
    func reports(limit: Int = 200) throws -> [Report] {
        guard let connection = self.openDB else {
            throw ViewDatabaseError.notOpen
        }
        let queryString = """
        SELECT
            reports.type AS report_type,
            reports.created_at AS created_at,
            messages.*,
            posts.*,
            contacts.*,
            contact_author.author AS contact_identifier,
            votes.*,
            messagekeys.*,
            authors.*,
            abouts.*,
            tangles.*,
            read_messages.is_read AS is_read
        FROM
            reports
            INNER JOIN messages ON (messages.msg_id = reports.msg_ref)
            LEFT OUTER JOIN posts ON (posts.msg_ref = messages.msg_id)
            LEFT OUTER JOIN contacts ON (contacts.msg_ref = messages.msg_id)
            LEFT JOIN authors AS contact_author ON contact_author.id = contacts.contact_id
            LEFT OUTER JOIN votes ON (votes.msg_ref = messages.msg_id)
            INNER JOIN messagekeys ON (messagekeys.id = messages.msg_id)
            INNER JOIN authors ON (authors.id = messages.author_id)
            INNER JOIN abouts ON (abouts.about_id = messages.author_id)
            LEFT OUTER JOIN tangles ON (tangles.msg_ref = messages.msg_id)
            LEFT OUTER JOIN read_messages ON (
                (read_messages.msg_id = messages.msg_id) AND (read_messages.author_id = reports.author_id)
            )
        WHERE
            reports.author_id = ?
            AND messages.hidden == false
        ORDER BY
            created_at DESC
        LIMIT
            ?
        """
        let reports = try connection.prepare(queryString, currentUserID, limit).prepareRowIterator().map { row in
            try buildReport(from: row)
        }
        return reports.compactMap { $0 }
    }

    /// Builds a Report object from a result query row
    private func buildReport(from row: Row) throws -> Report? {
        let msgKey = try row.get(colKey)
        let msgAuthor = try row.get(colAuthor)
        guard let value = try Value(row: row, db: self, hasMentionColumns: false) else {
            return nil
        }
        var keyValue = KeyValue(
            key: msgKey,
            value: value,
            timestamp: try row.get(colReceivedAt)
        )
        keyValue.metadata.author.about = About(
            about: msgAuthor,
            name: try row.get(colName),
            description: try row.get(colDescr),
            imageLink: try row.get(colImage)
        )
        keyValue.metadata.isPrivate = try row.get(colDecrypted)

        let rawReportType = try row.get(Expression<String>("report_type"))
        let reportType = ReportType(rawValue: rawReportType) ?? ReportType.messageLiked

        let createdAtTimestamp = try row.get(colCreatedAt)
        let createdAt = Date(timeIntervalSince1970: createdAtTimestamp / 1000)

        let isRead = try row.get(Expression<Bool?>("is_read")) ?? false
        var report = Report(
            authorIdentity: "undefined",
            messageIdentifier: msgKey,
            reportType: reportType,
            createdAt: createdAt,
            keyValue: keyValue
        )
        report.isRead = isRead
        return report
    }

    /// Counts the total number of reports since a given report.
    ///
    /// - parameter report: the offset
    ///
    /// This is useful for knowing if there are new reports since the last displayed one.
    func countNumberOfReports(since report: Report) throws -> Int {
        guard let connection = self.openDB else {
            throw ViewDatabaseError.notOpen
        }

        // swiftlint:disable indentation_width
        let queryString = """
        SELECT
          COUNT(*)
        FROM
          reports
        WHERE
          reports.author_id = ?
          AND created_at > ? + 1;
        """
        // swiftlint:enable indentation_width

        let query = try connection.prepare(queryString)
        if let count = try query.scalar(currentUserID, report.createdAt.millisecondsSince1970) as? Int64 {
            return Int(truncatingIfNeeded: count)
        }
        return 0
    }

    func feed(for identity: Identity, limit: Int = 5, offset: Int? = nil) throws -> KeyValues {
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
            wantPrivate: false  ,
            onlyRoots: true,
            offset: offset)
            .filter(colAuthorID == feedAuthorID)
            .order(colClaimedAt.desc)
            .filter(colClaimedAt <= Date().millisecondsSince1970)
            .filter(colHidden == false)

        let feedOfMsgs = try self.mapQueryToKeyValue(qry: postsQry)
        let msgs = try self.addNumberOfPeopleReplied(msgs: feedOfMsgs)
        let timeDone = CFAbsoluteTimeGetCurrent()
        print("\(#function) took \(timeDone - timeStart)")
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

    // MARK: - Read status

    func markMessageAsRead(identifier: MessageIdentifier, isRead: Bool = true) throws {
        guard let connection = self.openDB else {
            throw ViewDatabaseError.notOpen
        }
        let query = """
        INSERT OR REPLACE INTO read_messages (author_id, msg_id, is_read)
        VALUES (
        ?,
        (SELECT id FROM messagekeys WHERE key = ? LIMIT 1),
        ?)
        """
        try connection.prepare(query, currentUserID, identifier, isRead).run()
    }
    
    // MARK: - Fetching Posts
    
    func post(with id: MessageIdentifier) throws -> KeyValue {
        let msgId = try self.msgID(of: id, make: false)
        return try post(with: msgId)
    }
    
    func post(with messageRef: Int64) throws -> KeyValue {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }

        // TODO: add 2nd signature to get message by internal ID
        // guard let db = self.openDB else {
        //         throw ViewDatabaseError.notOpen
        //     }
        //     let msgId = try self.msgID(of: key, make: false)
        //
        //     return self.get(msgID: msgID)
        // }
        //
        // func get(msgID: Int64) throws -> KeyValue {
        
        let colTypeMaybe = Expression<String?>("type")
        let typeMaybe = try db.scalar(self.msgs
            .select(colTypeMaybe)
            .filter(colMessageID == messageRef)
            .filter(colHidden == false))

        guard let msgType = typeMaybe else {
            Log.unexpected(.botError, "[viewdb] should have type for this message: \(messageRef)")
            throw ViewDatabaseError.unknownMessage(String(messageRef))
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
                    .join(.leftOuter, self.abouts, on: self.abouts[colAboutID] == self.msgs[colAuthorID])
                    .filter(colMessageID == messageRef)
                    .limit(1)
                
                let kv = try self.mapQueryToKeyValue(qry: qry)
                
                if kv.count != 1 {
                    Log.unexpected(.botError, "[viewdb] could not find post after we had the type!?")
                    throw ViewDatabaseError.unknownMessage(String(messageRef))
                }
                return kv[0]
            
        default:
            throw ViewDatabaseError.unhandledContentType(ct)
        }
    }
    
    func posts(matching text: String) throws -> [KeyValue] {
        guard let connection = self.openDB else {
            throw ViewDatabaseError.notOpen
        }
        
        // probably need to escape some characters here
        var messages = [KeyValue]()
        let query = try connection.prepare(
            postSearch
                .filter(colText.match(text))
        )
        for row in query {
            let messageID = row[colMessageRef]
            let message = try post(with: messageID)
            messages.append(message)
        }
        
        return messages
    }
    
    // MARK: channels

    /// Returns a list of hashtags sorted by a given strategy
    func hashtags(with strategy: HashtagListStrategy) throws -> [Hashtag] {
        guard let connection = self.openDB else {
            throw ViewDatabaseError.notOpen
        }
        return try strategy.fetchHashtags(connection: connection, userId: currentUserID)
    }

    func hashtags(identity: Identity, limit: Int = 100) throws -> [Hashtag] {
        guard let connection = self.openDB else {
            throw ViewDatabaseError.notOpen
        }
        let queryString = """
        SELECT c.name AS channel_name
        FROM channel_assignments ca
        JOIN messages m ON m.msg_id = ca.msg_ref
        JOIN authors a ON a.id = m.author_id
        JOIN channels c ON c.id = ca.chan_ref
        WHERE a.author = ?
        ORDER BY m.received_at DESC
        LIMIT ? OFFSET 0;
        """
        let query = try connection.prepare(queryString)
        let bindings: [Binding?] = [
            identity,
            limit
        ]
        return try query.bind(bindings).prepareRowIterator().map { channelRow -> Hashtag in
            let channelName = try channelRow.get(Expression<String>("channel_name"))
            return Hashtag(name: channelName)
        }
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
            .order(colMessageID.desc)

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
                throw ViewDatabaseError.unknownHashtag(name)
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
        
        guard let address = msg.value.content.address,
              let multiserverAddress = address.multiserver else {
            Log.info("[viewdb/fill] broken addr message: \(msg.key)")
            return
        }
        
        let author = msg.value.author
        try saveAddress(feed: author, address: multiserverAddress, redeemed: nil)
    }
    
    func saveAddress(feed: Identity, address: MultiserverAddress, redeemed: Double?) throws {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }
        
        let authorID = try self.authorID(of: feed, make: true)
        
        let conflictStrategy = redeemed == nil ? OnConflict.ignore : OnConflict.replace
        
        try db.run(self.addresses.insert(or: conflictStrategy,
            colAboutID <- authorID,
            colAddress <- address.string,
            colRedeemed <- redeemed
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
    
    func deleteAbouts(for feed: FeedIdentifier) throws {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }
        
        let authorID = try authorID(of: feed, make: false)
        
        try db.transaction {
            try db.run(
                msgs
                    .filter(colMsgType == "about")
                    .filter(colAuthorID == authorID)
                    .delete()
            )
            
            try db.run(abouts.where(colAboutID == authorID).delete())
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

        var claimedMsg: KeyValue?
        do {
            claimedMsg = try self.post(with: dcr.hash)
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

        guard let p = msg.value.content.pub,
            p.address.key.isValidIdentifier else {
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
        
        try db.run(
            self.posts.insert(
                colMessageRef <- msgID,
                colIsRoot <- p.root == nil,
                colText <- p.text
            )
        )
        
        try db.run(
            postSearch.insert(
                colMessageRef <- msgID,
                colText <- p.text.lowercased()
            )
        )

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
    
    // needs to be update, this is just a copy o fillPost
    private func fillBlog(msgID: Int64, msg: KeyValue, pms: Bool) throws {
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
        
        try db.run(
            self.posts.insert(
                colMessageRef <- msgID,
                colIsRoot <- p.root == nil,
                colText <- p.text
            )
        )
        
        try db.run(
            postSearch.insert(
                colMessageRef <- msgID,
                colText <- p.text.lowercased()
            )
        )

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
        
        try self.insertBranches(msgID: msgID, root: v.vote.link, branches: [v.vote.link])
    }
    
    private func fillReportIfNeeded(msgID: Int64, msg: KeyValue, pms: Bool) throws -> [Report] {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }
        
        let createdAt = Date().timeIntervalSince1970 * 1_000
        
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
                                    createdAt: Date(timeIntervalSince1970: createdAt / 1_000),
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
                                            createdAt: Date(timeIntervalSince1970: createdAt / 1_000),
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
                                                createdAt: Date(timeIntervalSince1970: createdAt / 1_000),
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
                                                createdAt: Date(timeIntervalSince1970: createdAt / 1_000),
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
                                        createdAt: Date(timeIntervalSince1970: createdAt / 1_000),
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
        case .blog: //need to flush this out. blog.
            break
        case .unknown:
            break
        case .unsupported:
            break
        }
        return []
    }
    
    private func isOldMessage(message: KeyValue) -> Bool {
        let now = Date()
        let claimed = Date(timeIntervalSince1970: message.value.timestamp / 1000)
        let since = claimed.timeIntervalSince(now)
        return since < self.temporaryMessageExpireDate
    }
    
    func fillMessages(msgs: [KeyValue], pms: Bool = false) throws {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }
        
        Log.info("[rx log] starting fillMessages with \(msgs.count) new messages")

        #if SSB_MSGDEBUG
        // google claimed this is the tool to use to measure block execution time
        let start = CFAbsoluteTimeGetCurrent()
        // get an idea how many unsupported messages there are
        var unsupported: [String: Int] = [:]
        #endif
        
        var reports = [Report]()
        var skipped: UInt = 0
        var lastRxSeq: Int64 = -1
        
        let loopStart = Date().timeIntervalSince1970 * 1_000
        for msg in msgs {
            if let msgRxSeq = msg.receivedSeq {
                lastRxSeq = msgRxSeq
            } else {
                if !pms {
                    throw GoBotError.unexpectedFault("ViewDB: no receive sequence number on message")
                }
            }
            
            /* This is the don't put older than 6 months in the db. */
            if isOldMessage(message: msg) &&
                (msg.value.content.type != .contact &&
                msg.value.content.type != .about &&
                msg.value.author != currentUser) {
                // TODO: might need to mark viewdb if all messags are skipped... current bypass: just incease the receive batch size (to 15k)
                skipped += 1
                print("Skipped(\(msg.value.content.type) \(msg.key)%)")
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
                        
            if try authorMatchesBanList(msg) {
                // Insert the author into the authors table so we can tell the GoBot to ban them.
                _ = try self.authorID(of: msg.value.author, make: true)
                try ban(authors: [msg.value.author])
                skipped += 1
                print("Skipped banned (\(msg.value.content.type) \(msg.key)%)")
                continue
            }

            if try messageMatchesBanList(msg) {
                skipped += 1
                print("Skipped banned (\(msg.value.content.type) \(msg.key)%)")
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
                    colClaimedAt <- claimed,
                    colWrittenAt <- Date().millisecondsSince1970,
                    colOffChain <- msg.offChain ?? false
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
                        colClaimedAt <- claimed,
                        colWrittenAt <- Date().millisecondsSince1970,
                        colOffChain <- msg.offChain ?? false
                    ))
                } catch Result.error(let errMsg, let errCode, _) {
                    // this is _just_ here because of a fetch-duplication bug in go-ssb
                    // the constraints on the table are for uniquness:
                    // 1) message key/id
                    // 2) (author,sequence no)
                    // while (1) always means duplicate message (2) can also mean fork
                    // the problem is, SQLITE can throw (1) or (2) and we cant keep them apart here...
                    if errCode == SQLITE_CONSTRAINT {
                        skipped += 1
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
                    
                case .blog:
                    try self.fillBlog(msgID: msgKeyID, msg: msg, pms: pms)
                
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

        if !reports.isEmpty {
            NotificationCenter.default.post(
                name: Notification.Name("didCreateReport"),
                object: nil
            )
        }

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
            print("unsupported types encountered: \(total) (\(total * 100 / msgs.count)%)")
        }
        #endif

        Analytics.shared.trackBotDidUpdateMessages(count: msgs.count)

        if skipped > 0 {
            Log.info("[rx log] skipped \(skipped) messages.")
        }
        
        Log.info("[rx log] viewdb filled with \(msgs.count - Int(skipped)) messages.")
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

    func msgKey(id: Int64) throws -> MessageIdentifier {
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
    
    func authorID(of author: Identity, make: Bool = false) throws -> Int64 {
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
    
    /// Returns the total number of messages in the database
    func messageCount() throws -> Int {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }
        do {
            return try db.scalar(self.msgs.count)
        } catch {
            Log.optional(GoBotError.duringProcessing("messageCount failed", error))
            return 0
        }
    }
    
    /// - Parameter since: the date we want to check against.
    /// - Returns: The number of messages added to SQLite since the given date.
    func receivedMessageCount(since: Date) throws -> Int {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }
        do {
            return try db.scalar(
                self.msgs
                    .count
                    .filter(colWrittenAt > since.millisecondsSince1970)
                    .where(msgs[colAuthorID] != currentUserID)
            )
        } catch {
            Log.optional(GoBotError.duringProcessing("messageCount failed", error))
            return 0
        }
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
                colBranch <- try self.msgID(of: branch, make: true)
            ))
        }
    }
    
    private func insertMentions(msgID: Int64, mentions: [Mention]) throws {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }

        let notBlobs = mentions.filter { !$0.link.isBlob }
        for m in notBlobs {
            if !m.link.isValidIdentifier {
                continue
            }
            // TOOD: name might be a channel!
            switch m.link.sigil {
            case .message:
                try db.run(self.mentions_msg.insert(
                    colMessageRef <- msgID,
                    colLinkID <- try self.msgID(of: m.link, make: true)
                ))
            case .feed:
                try db.run(self.mentions_feed.insert(
                    colMessageRef <- msgID,
                    colFeedID <- try self.authorID(of: m.link, make: true),
                    colName <- m.name
                ))
            default:
                continue
            }
        }
    }
    
    func loadMentions(for msgID: Int64) throws -> [Mention] {
        // load mentions for this message
        let feedMentions = try loadFeedMentions(for: msgID)
        let msgMentions = try loadMessageMentions(for: msgID)
        
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
    
    func loadFeedMentions(for msgID: Int64) throws -> [Mention] {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }

        let feedQry = mentions_feed.where(colMessageRef == msgID)
        let feedMentions: [Mention] = try db.prepare(feedQry).map { mentionRow in

            let feedID = try mentionRow.get(colFeedID)
            let feed = try author(from: feedID)

            return Mention(
                link: feed,
                name: try mentionRow.get(colName) ?? ""
            )
        }

        return feedMentions
    }

    func loadMessageMentions(for msgID: Int64) throws -> [Mention] {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }

        let msgMentionQry = mentions_msg.where(colMessageRef == msgID)
        let msgMentions: [Mention] = try db.prepare(msgMentionQry).map { mentionRow in
            let linkID = try mentionRow.get(colLinkID)
            return Mention(
                link: try msgKey(id: linkID),
                name: ""
            )
        }

        return msgMentions
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

    func loadBlobs(for msgID: Int64) throws -> [Blob] {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }
        
        // let supportedMimeTypes = [MIMEType.jpeg, MIMEType.png]
        
        let qry = self.post_blobs.where(colMessageRef == msgID)
        
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
    
    /// Returns the number of messages posted by given feed identifier
    func numberOfMessages(for feed: FeedIdentifier) throws -> Int {
        guard let db = self.openDB else {
            throw ViewDatabaseError.notOpen
        }
        do {
            let authorID = try self.authorID(of: feed, make: false)
            return try db.scalar(
                msgs
                    .filter(colAuthorID == authorID)
                    .filter(colOffChain == false)
                    .count
            )
        } catch {
            Log.optional(GoBotError.duringProcessing("numberOfmessages for feed failed", error))
            return 0
        }
    }
} // end class
