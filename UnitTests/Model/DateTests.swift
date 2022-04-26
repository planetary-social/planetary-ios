//
//  DateTests.swift
//  FBTTUnitTests
//
//  Created by Christoph on 7/13/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import XCTest

class DateTests: XCTestCase {

    func test_randomDate() {
        XCTAssertEqual(Calendar.current.component(.year, from: Date.random(in: 1_975)), 1_975)
        XCTAssertEqual(Calendar.current.component(.year, from: Date.random(in: 2_040)), 2_040)
        XCTAssertFalse(Calendar.current.component(.year, from: Date.random(in: 0)) == 0)
    }

    func test_minimumAge() {
        XCTAssertTrue(Date.random(yearsFromNow: -20).olderThan(yearsAgo: 16))
        XCTAssertFalse(Date.random(yearsFromNow: -10).olderThan(yearsAgo: 16))
        let now = Date()
        let year = Calendar.current.component(.year, from: now) - 16
        let month = Calendar.current.component(.month, from: now)
        let day = Calendar.current.component(.day, from: now)
        let birthdate = Date.year(year, month: month, day: day)!
        let before = Calendar.current.date(byAdding: .day, value: -1, to: birthdate)!
        let after = Calendar.current.date(byAdding: .day, value: 1, to: birthdate)!
        XCTAssertTrue(before.olderThan(yearsAgo: 16))
        XCTAssertFalse(after.olderThan(yearsAgo: 16))
    }

    func test_elapsedTimeFromNow() {

        // dates from the past
        XCTAssertTrue(Date().elapsedTimeFromNowString() == "1m")
        XCTAssertTrue(Date(timeIntervalSinceNow: 60 * -1).elapsedTimeFromNowString() == "1m")
        XCTAssertTrue(Date(timeIntervalSinceNow: 60 * -3).elapsedTimeFromNowString() == "3m")
        XCTAssertTrue(Date(timeIntervalSinceNow: 60 * -59).elapsedTimeFromNowString() == "59m")
        XCTAssertTrue(Date(timeIntervalSinceNow: 60 * -61).elapsedTimeFromNowString() == "1h")
        XCTAssertTrue(Date(timeIntervalSinceNow: 60 * 60 * -3).elapsedTimeFromNowString() == "3h")
        XCTAssertEqual(Date(timeIntervalSinceNow: 60 * 60 * 24 * -3).elapsedTimeFromNowString(), "3d")
        XCTAssertEqual(Date(timeIntervalSinceNow: 60 * 60 * 24 * -6).elapsedTimeFromNowString(), "6d")
        XCTAssertTrue(Date(timeIntervalSinceNow: 60 * 60 * 24 * -7).elapsedTimeFromNowString() != "7d")

        // dates from the future
        XCTAssertEqual(Date(timeIntervalSinceNow: 60 * 1).elapsedTimeFromNowString(), "In the future")
        XCTAssertEqual(Date(timeIntervalSinceNow: 60 * 3).elapsedTimeFromNowString(), "In the future")
        XCTAssertEqual(Date(timeIntervalSinceNow: 60 * 59).elapsedTimeFromNowString(), "In the future")
        XCTAssertEqual(Date(timeIntervalSinceNow: 60 * 61).elapsedTimeFromNowString(), "In the future")
        XCTAssertEqual(Date(timeIntervalSinceNow: 60 * 60 * 3).elapsedTimeFromNowString(), "In the future")
        XCTAssertEqual(Date(timeIntervalSinceNow: 60 * 60 * 24 * 3).elapsedTimeFromNowString(), "In the future")
        XCTAssertEqual(Date(timeIntervalSinceNow: 60 * 60 * 24 * 6).elapsedTimeFromNowString(), "In the future")
    }

    func test_iso8601() {

        // transform a single date
        // note that if the date component fails to create a date
        // the test will fail because it will not match the ISO string
        var components = DateComponents()
        components.year = 2_012
        components.month = 12
        components.day = 12
        components.hour = 12
        components.minute = 12
        components.second = 12
        components.timeZone = TimeZone(secondsFromGMT: 0)
        let date = Calendar.current.date(from: components) ?? Date()
        // TODO: This fails on Zef's machine, which is in a different time zone
        // the faling result is "2012-12-12T19:12:12Z"
        // https://app.asana.com/0/1140308184568993/1144083857934697/f
        XCTAssertTrue(date.iso8601String == "2012-12-12T12:12:12Z")

        // transform a dictionary
        let dictionary: [String: Any] = ["date": date, "ignore": true]
        let transformed = dictionary.copyByTransformingValues(of: Date.self) {
            value in
            value.iso8601String
        }
        XCTAssertTrue(transformed.count == 2)
        XCTAssertTrue((transformed["date"] as? String) == "2012-12-12T12:12:12Z")

        // transformed dictionary should serialize
        // transformed should serialize the same as original
        let dictionaryData = dictionary.data()
        let transformedData = transformed.data()
        XCTAssertNotNil(dictionaryData)
        XCTAssertNotNil(transformedData)
        XCTAssertTrue(dictionaryData?.count == transformedData?.count)
    }
}
