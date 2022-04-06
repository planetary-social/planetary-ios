//
//  Collection+RandomSample.swift
//  FBTT
//
//  Created by Henry Bubert on 05.08.19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

extension Collection {

    /**
     * Returns a random element of the Array or nil if the Array is empty.
     */
    func randomSample() -> Element? {
        guard !isEmpty else { return nil }
        let offset = arc4random_uniform(numericCast(self.count))
        let idx = self.index(self.startIndex, offsetBy: numericCast(offset))
        return self[idx]
    }

    /**
     * Returns `count` random elements from the array.
     * If there are not enough elements in the Array, a smaller Array is returned.
     * Elements will not be returned twice except when there are duplicate elements in the original Array.
     */
    func randomSample(_ count: UInt) -> [Element] {
        let sampleCount = Swift.min(numericCast(count), self.count)

        var elements = Array(self)
        var samples: [Element] = []

        while samples.count < sampleCount {
            let idx = (0..<elements.count).randomSample()!
            samples.append(elements.remove(at: idx))
        }

        return samples
    }
}
