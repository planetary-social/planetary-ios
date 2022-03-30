//
//  Array+SafeSubscript.swift
//  FBTT
//
//  Created by Christoph on 5/2/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

extension Array {

    subscript (safe index: Index) -> Element? {
        0 <= index && index < count ? self[index] : nil
    }

    var nextToLast: Element? {
        if self.count <= 1 { return nil }
        return self[safe: self.count - 2]
    }
}
