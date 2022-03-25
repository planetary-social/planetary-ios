//
//  Dictionary+JSONSerialization.swift
//  FBTT
//
//  Created by Christoph on 7/9/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

extension Dictionary {

    func data() -> Data? {
        let dictionary = self.copyByTransformingValues(of: Date.self) {
            date in
            date.iso8601String
        }
        return try? JSONSerialization.data(withJSONObject: dictionary, options: .prettyPrinted)
    }
}
