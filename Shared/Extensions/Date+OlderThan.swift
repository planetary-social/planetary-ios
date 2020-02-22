//
//  Date+OlderThan.swift
//  FBTT
//
//  Created by Christoph on 7/13/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

extension Date {

    static func year(_ year: Int, month: Int, day: Int) -> Date? {
        let components = DateComponents(calendar: Calendar.current,
                                        year: year,
                                        month: month,
                                        day: day)
        return components.date
    }

    func olderThan(yearsAgo: Int) -> Bool {
        guard yearsAgo > 0 else { return false }
        guard let date = Calendar.current.date(byAdding: .year, value: -yearsAgo, to: Date()) else { return false }
        return self < date
    }
}
