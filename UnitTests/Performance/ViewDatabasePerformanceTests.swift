//
//  ViewDatabasePerformanceTests.swift
//  UnitTests
//
//  Created by Matthew Lorentz on 1/13/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import XCTest
@testable import Planetary

/// Tests to measure performance of `ViewDatabase`
class ViewDatabasePerformanceTests: XCTestCase {

    var dbURL: URL!
    var vdb = ViewDatabase()
    let testFeed = DatabaseFixture.bigFeed
    
    override func setUpWithError() throws {
        vdb.close()
        vdb = ViewDatabase()
        let dbDir = NSURL.fileURL(withPathComponents: [NSTemporaryDirectory(), "ViewDatabaseBenchmarkTests"])!
        dbURL = NSURL.fileURL(withPathComponents: [
            NSTemporaryDirectory(),
            "ViewDatabaseBenchmarkTests",
            "schema-built\(ViewDatabase.schemaVersion).sqlite"
        ])!
        try? FileManager.default.removeItem(at: dbURL)
        try FileManager.default.createDirectory(at: dbDir, withIntermediateDirectories: true)
        let sqliteURL = Bundle(for: type(of: self)).url(forResource: "Feed_big", withExtension: "sqlite")!
        try FileManager.default.copyItem(at: sqliteURL, to: dbURL)
        
        // open DB
        let dbDirPath = dbDir.absoluteString.replacingOccurrences(of: "file://", with: "")
        let maxAge: Double = -60 * 60 * 24 * 30 * 48  // 48 month (so roughtly until 2023)
        try vdb.open(path: dbDirPath, user: testFeed.owner, maxAge: maxAge)
    }
    
    override func tearDownWithError() throws {
        vdb.close()
        try FileManager.default.removeItem(at: self.dbURL)
    }
    
    func resetDB() throws {
        try tearDownWithError()
        try setUpWithError()
    }

    /// Measures the peformance of `fillMessages(msgs:)`. This is the function that is called to copy posts from go-ssb
    /// to sqlite.
    func testFillMessages() throws {
        let data = self.data(for: DatabaseFixture.bigFeed.fileName)

        var urls: [URL] = []
        // get test messages from JSON
        let msgs = try JSONDecoder().decode([KeyValue].self, from: data)
        XCTAssertNotNil(msgs)
        XCTAssertEqual(msgs.count, 2_500)
        
        self.measure {
            let vdb = ViewDatabase()
            let tmpURL = NSURL.fileURL(withPathComponents: [NSTemporaryDirectory(), NSUUID().uuidString])!
            try! FileManager.default.createDirectory(at: tmpURL, withIntermediateDirectories: true)
            
            vdb.close() // close init()ed version...
            
            urls += [tmpURL] // don't litter
            
            let  damnPath = tmpURL.absoluteString.replacingOccurrences(of: "file://", with: "")
            try! vdb.open(path: damnPath, user: testFeed.secret.identity)
            
            try! vdb.fillMessages(msgs: msgs)
            
            vdb.close()
        }
        
        print("dropping \(urls.count) runs") // clean up
        for u in urls {
            try FileManager.default.removeItem(at: u)
        }
    }

    func testCurrentPostsAlgorithm() throws {
        let strategy = PostsAlgorithm(wantPrivate: false, onlyFollowed: false)
        measureMetrics([XCTPerformanceMetric.wallClockTime], automaticallyStartMeasuring: false) {
            startMeasuring()
            let keyValues = try! self.vdb.recentPosts(strategy: strategy, limit: 100, offset: 0)
            XCTAssertEqual(keyValues.count, 100)
            stopMeasuring()
        }
    }

    func testPostsAndContactsAlgorithm() throws {
        let strategy = PostsAndContactsAlgorithm()
        measureMetrics([XCTPerformanceMetric.wallClockTime], automaticallyStartMeasuring: false) {
            startMeasuring()
            let keyValues = try! self.vdb.recentPosts(strategy: strategy, limit: 100, offset: 0)
            XCTAssertEqual(keyValues.count, 100)
            stopMeasuring()
        }
    }
    
    func testGetFollows() {
        measureMetrics([XCTPerformanceMetric.wallClockTime], automaticallyStartMeasuring: false) {
            startMeasuring()
            for _ in 0..<30 { // artificially inflate times to meet 0.1 second threshold, otherwise test will never fail.
                for feed in testFeed.identities {
                    let _: [Identity] = try! self.vdb.getFollows(feed: feed)
                }
            }
            stopMeasuring()
            try! resetDB()
        }
    }
    
    func testFeedForIdentity() {
        measureMetrics([XCTPerformanceMetric.wallClockTime], automaticallyStartMeasuring: false) {
            startMeasuring()
            _ = try! self.vdb.feed(for: testFeed.identities[0])
            stopMeasuring()
            try! resetDB()
        }
    }

    /// This test performs a lot of feed loading (reads) while another thread is writing to the SQLite database. The
    /// reader threads are expected to finish before the long write does, verifying that we are optimizing for
    /// reading (see ADR #4).
    func testSimultanousReadsAndWrites() throws {
        let data = self.data(for: DatabaseFixture.bigFeed.fileName)
        let msgs = try JSONDecoder().decode([KeyValue].self, from: data)
        
        measure {
            var writerIsFinished = false
            let writesFinished = self.expectation(description: "Writes finished")
            let writer = {
                try! self.vdb.fillMessages(msgs: msgs)
                
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
                    _ = try! self.vdb.feed(for: self.testFeed.identities[0])
                    
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
            
            waitForExpectations(timeout: 10)
        }
    }
}
