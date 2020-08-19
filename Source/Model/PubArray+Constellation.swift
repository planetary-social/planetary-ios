//
//  PubArray+Constellation.swift
//  Planetary
//
//  Created by Martin Dutra on 8/17/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation

extension Array where Element == Pub {
    
    func filterInConstellation() -> [Pub] {
        let stars = Environment.Constellation.stars
        return self.filter { (pub) -> Bool in
            return stars.contains { (star) -> Bool in
                return star.feed == pub.address.key
            }
        }
    }
    
}
