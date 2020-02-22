//
//  CacheTests.swift
//  UnitTests
//
//  Created by Christoph on 11/20/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import XCTest
import UIKit

class CacheTests: XCTestCase {

    func test_DictionaryCache() {

        let cache = DictionaryCache()
        XCTAssertTrue(cache.count == 0)
        XCTAssertTrue(cache.estimatedBytes == 0)

        // DictionaryCache has no implementation to count bytes
        // so estimatedBytes should always be 0
        for i in 1...10 { cache.update(Data(), for: "\(i)") }
        XCTAssertTrue(cache.count == 10)
        XCTAssertTrue(cache.estimatedBytes == 0)

        cache.invalidate()
        XCTAssertTrue(cache.count == 0)
        XCTAssertTrue(cache.estimatedBytes == 0)
    }

    func test_BlobCacheEstimatedBytes() {

        let cache = BlobCache()
        var totalCount = 0
        for i in 1...10 {
            let image = UIColor.red.image(dimension: 100)
            totalCount += image.numberOfBytes
            cache.update(image, for: "\(i)")
        }
        XCTAssertTrue(cache.estimatedBytes == totalCount)

        cache.invalidateItem(for: "1")
        XCTAssertTrue(cache.count == 9)
        XCTAssertFalse(cache.estimatedBytes == totalCount)

        cache.invalidate()
        XCTAssertTrue(cache.count == 0)
        XCTAssertTrue(cache.estimatedBytes == 0)
    }

    func test_BlobCacheSortedItems() {

        let cache = BlobCache()
        for i in 1...10 {
            let image = UIColor.red.image(dimension: 100)
            cache.update(image, for: "\(i)")
        }

        // keys 1 to 10 ascending
        var key = 1
        var items = cache.itemsSortedByDateAscending()
        for item in items {
            XCTAssertTrue(item.key == "\(key)")
            key += 1
        }

        cache.invalidate()
        XCTAssertTrue(cache.count == 0)

        for i in (1...10).reversed() {
            let image = UIColor.red.image(dimension: 100)
            cache.update(image, for: "\(i)")
        }

        // keys 10 to 1 descending
        key = 10
        items = cache.itemsSortedByDateAscending()
        for item in items {
            XCTAssertTrue(item.key == "\(key)")
            key -= 1
        }
    }
}
