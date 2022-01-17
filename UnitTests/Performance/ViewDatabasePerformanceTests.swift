//
//  ViewDatabasePerformanceTests.swift
//  UnitTests
//
//  Created by Matthew Lorentz on 1/13/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import XCTest

/// Tests to measure performance of `ViewDatabase`
class ViewDatabasePerformanceTests: XCTestCase {
    
    var dbURL: URL!
    var vdb = ViewDatabase()
    let testFeed = DatabaseFixture.bigFeed
    
    override func setUpWithError() throws {
        vdb.close()
        vdb = ViewDatabase()
        let dbDir = NSURL.fileURL(withPathComponents: [NSTemporaryDirectory(), "ViewDatabaseBenchmarkTests"])!
        dbURL = NSURL.fileURL(withPathComponents: [NSTemporaryDirectory(), "ViewDatabaseBenchmarkTests", "schema-built\(ViewDatabase.schemaVersion).sqlite"])!
        try? FileManager.default.removeItem(at: dbURL)
        try FileManager.default.createDirectory(at: dbDir, withIntermediateDirectories: true)
        let sqliteURL = Bundle(for: type(of: self)).url(forResource: "Feed_big", withExtension: "sqlite")!
        try FileManager.default.copyItem(at: sqliteURL, to: dbURL)
        
        // open DB
        let dbDirPath = dbDir.absoluteString.replacingOccurrences(of: "file://", with: "")
        try vdb.open(path: dbDirPath, user: testFeed.owner, maxAge: -60*60*24*30*48) // 48 month (so roughtly until 2023)
    }
    
    override func tearDown() {
        vdb.close()
        try! FileManager.default.removeItem(at: self.dbURL)
    }
    
    func resetDB() throws {
        tearDown()
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
        XCTAssertEqual(msgs.count, 2500)
        
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
            let _ = try! self.vdb.feed(for: testFeed.identities[0])
            stopMeasuring()
            try! resetDB()
        }
    }
    
    /// This test performs a lot of feed loading (reads) while another thread is writing to the SQLite database.
    /// This test is designed to stress the database and verify that we are optimizing for reading (see ADR #4).
    func testSimultanousReadsAndWrites() throws {
        let data = self.data(for: DatabaseFixture.bigFeed.fileName)
        let msgs = try JSONDecoder().decode([KeyValue].self, from: data)
        
        measure {

            let writesFinished = self.expectation(description: "Writes finished")
            var expectations = [writesFinished]
            let writer = {
                try! self.vdb.fillMessages(msgs: msgs)
                writesFinished.fulfill()
            }
            
            var readers = [() -> Void]()
            for i in 0..<100 {
                let readFinished = self.expectation(description: "Read \(i) finished")
                expectations.append(readFinished)
                let reader = { [self] in
                    let _ = try! self.vdb.feed(for: self.testFeed.identities[0])
                    print("Reader \(i) finished")
                    readFinished.fulfill()
                }
                
                readers.append(reader)
            }
            
            let writeQueue = DispatchQueue(label: "write")

            writeQueue.async {
                writer()
            }
            
            for (i, reader) in readers.enumerated() {
                let readQueue = DispatchQueue(label: "readQueue \(i)")

                readQueue.async {
                    reader()
                }
            }
            
            self.wait(for: expectations, timeout: 10)
        }
    }
}
