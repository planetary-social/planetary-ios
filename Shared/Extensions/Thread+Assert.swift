//
//  Thread+Assert.swift
//  FBTT
//
//  Created by Christoph on 4/29/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

extension Thread {
    static func assertIsMainThread() {
        assert(Thread.isMainThread)
    }
}
