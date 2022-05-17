//
//  Date+Elapsed.swift
//  FBTT
//
//  Created by Christoph on 8/6/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

extension Date {

    func elapsedTimeFromNowString() -> String {

        // from and to dates
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        let from = calendar.dateComponents([.timeZone, .minute, .hour, .day, .month, .year], from: self)
        let to = calendar.dateComponents([.timeZone, .minute, .hour, .day, .month, .year], from: Date())

        // TODO https://app.asana.com/0/914798787098068/1148032440727609/f
        // TODO this is off by one hour during the daylight savings switch (for 24 hours only)
        // compute delta
        let delta = calendar.dateComponents([.timeZone, .minute, .hour, .day], from: from, to: to)
        let minutes = delta.minute ?? -1
        let hours = delta.hour ?? -1
        let day = delta.day ?? -1

        // catch any future dates
        if minutes < 0 || hours < 0 || day < 0 {
            return "In the future"
        }

        switch day {
        case 0:
            // at least 1 minute ago
            if hours == 0 { return "\(max(1, minutes))m" }

            // at least 1 hour ago
            else { return "\(hours)h" }

        // 1 to 7 days ago
        case 1..<7:
            return "\(day)d"

        // July 29
        default:
            let formatter = DateFormatter()
            formatter.timeStyle = .none
            formatter.dateFormat = "MMMM dd YYYY"
            return formatter.string(from: self)
        }
    }
}
