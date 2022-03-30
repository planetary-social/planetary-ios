//
//  Date+ISO8601.swift
//  FBTT
//
//  Created by Christoph on 8/13/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

extension Date {

    private static let iso8601Formatter = ISO8601DateFormatter()

    var iso8601String: String {
        Date.iso8601Formatter.string(from: self)
    }
}
