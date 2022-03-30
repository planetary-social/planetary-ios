//
//  Date+Random.swift
//  FBTT
//
//  Created by Christoph on 7/13/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

extension Date {

    /// Convenience to generate a date within a specific year.  Note that the actual days
    /// are limited to the 12 months and 28 days per month, to avoid dates that are illegal
    /// for a particular year (like a leap year).
    static func random(in year: UInt) -> Date {
        let components = DateComponents(calendar: Calendar.current,
                                        year: Int(year),
                                        month: Int(arc4random() % 11) + 1,
                                        day: Int(arc4random() % 27) + 1)
        return components.date ?? Date()
    }

    static func random(yearsFromNow: Int) -> Date {
        let year = Calendar.current.component(.year, from: Date())
        return Date.random(in: UInt(year + yearsFromNow))
    }

    var shortDateString: String {
        DateFormatter.localizedString(from: self,
                                             dateStyle: .short,
                                             timeStyle: .none)
    }

    var shortDateTimeString: String {
        DateFormatter.localizedString(from: self,
                                             dateStyle: .short,
                                             timeStyle: .short)
    }
}
