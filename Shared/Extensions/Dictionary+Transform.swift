//
//  Dictionary+Transform.swift
//  FBTT
//
//  Created by Christoph on 8/13/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

extension Dictionary {

    // This could support an array of transforms to prevent
    // looping multiple times for multiple value types.
    func copyByTransformingValues<T: Any>(of type: T.Type,
                                          using: ((T) -> String)) -> [Key: Any] {
        var dictionary: [Key: Any] = [:]
        self.forEach {
            if let value = $0.value as? T { dictionary[$0.key] = using(value) } else { dictionary[$0.key] = $0.value }
        }
        return dictionary
    }
}
