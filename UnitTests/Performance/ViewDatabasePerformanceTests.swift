//
//  ViewDatabasePerformanceTests.swift
//  UnitTests
//
//  Created by Matthew Lorentz on 1/13/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import XCTest

// swiftlint:disable implicitly_unwrapped_optional force_try

/// Tests to measure performance of `ViewDatabase`.
class ViewDatabasePerformanceTests: XCTestCase {

    var dbURL: URL!
    var viewDatabase = ViewDatabase()
    let testFeed = DatabaseFixture.bigFeed
    var dbDirPath: String!
    var maxAge: Double!
    
    override func setUpWithError() throws {
        try setUpSmallDB()
        try super.setUpWithError()
    }
    
    override func tearDown() async throws {
        await viewDatabase.close()
        try FileManager.default.removeItem(at: self.dbURL)
        try await super.tearDown()
    }
    
    /// Creates a directory where we can initialize a database for the tests and returns the URL to it.
    private func createDBDirectory() async throws -> URL {
        viewDatabase = ViewDatabase()
        let dbDir = FileManager
            .default
            .temporaryDirectory
            .appendingPathComponent("ViewDatabaseBenchmarkTests")
            .appendingPathComponent(UUID().uuidString)
        dbURL = dbDir.appendingPathComponent("schema-built\(ViewDatabase.schemaVersion).sqlite")
        try FileManager.default.createDirectory(at: dbDir, withIntermediateDirectories: true)
        return dbDir
    }
    
    private func openDB(in directory: URL, user: Identity) throws {
        dbDirPath = directory.absoluteString.replacingOccurrences(of: "file://", with: "")
        try viewDatabase.open(path: dbDirPath, user: user, maxAge: -.infinity)
    }
    
    private func setUpEmptyDB(user: Identity) throws {
        let setupExpectation = expectation(description: "setup")
        // Performance tests do not work with async/await yet so we wrap these calls in a Task and use an expecatation
        // to wait on it.
        Task {
            let dbDir = try await createDBDirectory()
            try openDB(in: dbDir, user: user)
            setupExpectation.fulfill()
        }
        wait(for: [setupExpectation], timeout: 20)
    }
    
    private func setUpSmallDB() throws {
        try loadDB(named: "Feed_big", user: testFeed.owner)
    }
    
    private func loadDB(named dbName: String?, user: Identity) throws {
        // Performance tests do not with with async/await yet so we wrap these calls in a Task and use an expecatation
        // to wait on it.
        let setupExpectation = expectation(description: "setup")
        Task {
            let dbDir = try await createDBDirectory()
            let sqliteURL = try XCTUnwrap(Bundle(for: type(of: self)).url(forResource: dbName, withExtension: "sqlite"))
            try FileManager.default.copyItem(at: sqliteURL, to: dbURL)
            try openDB(in: dbDir, user: user)
            setupExpectation.fulfill()
        }
        wait(for: [setupExpectation], timeout: 20)
    }
    
    func resetSmallDB() throws {
        try setUpSmallDB()
    }
    
    /// Measures the peformance of `fillMessages(msgs:)`. This is the function that is called to copy posts from go-ssb
    /// to sqlite.
    func testFillMessagesGivenSmallDB() throws {
        let data = self.data(for: DatabaseFixture.bigFeed.fileName)

        // get test messages from JSON
        let msgs = try JSONDecoder().decode([Message].self, from: data)
        XCTAssertNotNil(msgs)
        XCTAssertEqual(msgs.count, 2500)
        
        measureMetrics([XCTPerformanceMetric.wallClockTime], automaticallyStartMeasuring: false) {
            try! self.setUpEmptyDB(user: testFeed.owner)
            startMeasuring()
            try? viewDatabase.fillMessages(msgs: msgs)
            stopMeasuring()
        }
    }

    func testDiscoverAlgorithmGivenSmallDb() throws {
        let strategy = PostsAlgorithm(wantPrivate: false, onlyFollowed: false)
        measureMetrics([XCTPerformanceMetric.wallClockTime], automaticallyStartMeasuring: false) {
            try! resetSmallDB()
            startMeasuring()
            let messages = try? self.viewDatabase.recentPosts(strategy: strategy, limit: 100, offset: 0)
            XCTAssertEqual(messages?.count, 100)
            stopMeasuring()
        }
    }
    
    func testCurrentPostsAlgorithmGivenSmallDb() throws {
        let strategy = PostsAlgorithm(wantPrivate: false, onlyFollowed: true)
        measureMetrics([XCTPerformanceMetric.wallClockTime], automaticallyStartMeasuring: false) {
            try! resetSmallDB()
            startMeasuring()
            let messages = try? self.viewDatabase.recentPosts(strategy: strategy, limit: 100, offset: 0)
            XCTAssertEqual(messages?.count, 91)
            stopMeasuring()
        }
    }
    
    func testPostsAndContactsAlgorithmGivenSmallDB() throws {
        let strategy = PostsAndContactsAlgorithm()
        measureMetrics([XCTPerformanceMetric.wallClockTime], automaticallyStartMeasuring: false) {
            try! resetSmallDB()
            startMeasuring()
            let messages = try? self.viewDatabase.recentPosts(strategy: strategy, limit: 100, offset: 0)
            XCTAssertEqual(messages?.count, 100)
            stopMeasuring()
        }
    }
    
    func testRecentlyActivePostsAndContactsAlgorithmGivenSmallDB() throws {
        let strategy = RecentlyActivePostsAndContactsAlgorithm()
        measureMetrics([XCTPerformanceMetric.wallClockTime], automaticallyStartMeasuring: false) {
            try! resetSmallDB()
            startMeasuring()
            let keyValues = try? self.viewDatabase.recentPosts(strategy: strategy, limit: 100, offset: 0)
            XCTAssertEqual(keyValues?.count, 100)
            stopMeasuring()
        }
    }
    
    func testCountNumberOfKeysSinceUsingRecentlyActivePostsAndContactsAlgorithmGivenSmallDB() throws {
        try! resetSmallDB()
        let strategy = RecentlyActivePostsAndContactsAlgorithm()
        let messages = try self.viewDatabase.recentPosts(strategy: strategy, limit: 100, offset: 0)
        let earliestMessage = try XCTUnwrap(messages.last)
        measureMetrics([XCTPerformanceMetric.wallClockTime], automaticallyStartMeasuring: false) {
            try! resetSmallDB()
            startMeasuring()
            let newMessageCount = try? self.viewDatabase.numberOfRecentPosts(with: strategy, since: earliestMessage.key)
            XCTAssertEqual(newMessageCount, 100)
            stopMeasuring()
        }
    }
    
    func testGetFollows() {
        measureMetrics([XCTPerformanceMetric.wallClockTime], automaticallyStartMeasuring: false) {
            try! resetSmallDB()
            startMeasuring()
            for _ in 0..<30 {
                // artificially inflate times to meet 0.1 second threshold, otherwise test will never fail.
                for feed in testFeed.identities {
                    _ = try? self.viewDatabase.getFollows(feed: feed) as [Identity]
                }
            }
            stopMeasuring()
            try? resetSmallDB()
        }
    }
    
    func testFeedForIdentity() {
        measureMetrics([XCTPerformanceMetric.wallClockTime], automaticallyStartMeasuring: false) {
            try! resetSmallDB()
            startMeasuring()
            _ = try? self.viewDatabase.feed(for: testFeed.identities[0])
            stopMeasuring()
        }
    }
    
    func testCountNumberOfFollowersAndFollows() {
        resetSmallDBAndMeasure {
            for _ in 0..<100 {
                _ = try? self.viewDatabase.countNumberOfFollowersAndFollows(feed: testFeed.identities[0])
            }
        }
    }
    
    /// This test performs a lot of feed loading (reads) while another thread is writing to the SQLite database. The
    /// reader threads are expected to finish before the long write does, verifying that we are optimizing for
    /// reading (see ADR #4).
    func testSimultanousReadsAndWrites() throws {
        let data = self.data(for: DatabaseFixture.bigFeed.fileName)
        let msgs = try JSONDecoder().decode([Message].self, from: data)
        
        measureMetrics([XCTPerformanceMetric.wallClockTime], automaticallyStartMeasuring: false) {
            try! resetSmallDB()
            startMeasuring()
            var writerIsFinished = false
            let writesFinished = self.expectation(description: "Writes finished")
            let writer = {
                try? self.viewDatabase.fillMessages(msgs: msgs)
                
                // Synchronize the writerIsFinished property because readers may be using it from other threads.
                objc_sync_enter(self)
                writerIsFinished = true
                objc_sync_exit(self)
                writesFinished.fulfill()
            }
            
            var readers = [() -> Void]()
            for i in 0..<100 {
                let readFinished = self.expectation(description: "Read \(i) finished")
                let reader = { [self] in
                    _ = try? self.viewDatabase.feed(for: self.testFeed.identities[0])
                    
                    // Verify that we weren't blocked by the writer.
                    objc_sync_enter(self)
                    XCTAssertEqual(writerIsFinished, false)
                    objc_sync_exit(self)
                    readFinished.fulfill()
                }
                
                readers.append(reader)
            }
            
            DispatchQueue(label: "write").async {
                writer()
            }
            
            for (i, reader) in readers.enumerated() {
                DispatchQueue(label: "readQueue \(i)").async {
                    reader()
                }
            }
            
            waitForExpectations(timeout: 20)
            stopMeasuring()
        }
    }
    
    private func resetSmallDBAndMeasure(_ block: () -> Void) {
        measureMetrics([XCTPerformanceMetric.wallClockTime], automaticallyStartMeasuring: false) {
            try! resetSmallDB()
            startMeasuring()
            block()
            stopMeasuring()
        }
    }
}
