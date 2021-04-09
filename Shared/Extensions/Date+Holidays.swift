//
//  Date+Holidays.swift
//  Planetary
//
//  Created by Christoph on 12/18/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

extension Date {

    private static let holidayDayMonths: [(day: Int, month: Int)] = [
        (day: 24, month: 12),
        (day: 25, month: 12),
        (day: 31, month: 12),
        (day: 1, month: 1),
        (day: 19, month: 4)
    ]

    static func todayIsAHoliday() -> Bool {
        let components = Calendar.current.dateComponents([.month, .day], from: Date())
        for holiday in Date.holidayDayMonths {
            if components.day == holiday.day && components.month == holiday.month {
                return true
            }
        }
        return false
    }
}
