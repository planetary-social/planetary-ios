//
//  URLRequest+APIHeaders.swift
//  FBTT
//
//  Created by Christoph on 6/14/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

extension URLRequest {

    mutating func add(_ headers: APIHeaders) {
        for header in headers {
            self.addValue(header.value, forHTTPHeaderField: header.key)
        }
    }
}
