//
//  Hashtag.swift
//  FBTT
//
//  Created by Christoph on 7/11/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

/// This is not a direct SSB model, but is rather a view model that contains a
/// a name from the Bot and the view database.
/// Checkout Bot+Hashtag to see how a hashtag is created from String name
/// and returned as a Hashtag model.
struct Hashtag: Codable {

    // name is raw unadorned characters after #
    let name: String
    let count: Int64
    let timestamp: Float64 // received time
    
    // string is # prefixed name
    var string: String {
        return "#\(self.name)"
    }

    static func named(_ name: String) -> Hashtag {
        return Hashtag(name: name.withoutHashPrefix)
    }

    init(name: String) {
        self.name = name
        self.count = 0
        self.timestamp = 0
    }
    
    init(name: String, count: Int64) {
        self.name = name
        self.count = count
        self.timestamp = 0
    }
    
    init(name: String, count: Int64, timestamp: Float64) {
        self.name = name
        self.count = count
        self.timestamp = timestamp
    }
    
    init(name: String, timestamp: Float64) {
        self.name = name
        self.count = 0
        self.timestamp = timestamp
    }
    
    init(from decoder: Decoder) throws {
        self.name = try decoder.singleValueContainer().decode(String.self)
        self.count = 0
        self.timestamp = 0
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.name)
    }
    
    func timeAgo() -> String {
        var relativeDate = ""
        if #available(iOS 13.0, *) {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full

            let date = Date(timeIntervalSince1970: TimeInterval(self.timestamp) / 1000)
            relativeDate = formatter.localizedString(for: date, relativeTo: Date())

        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "E, d MMM yyyy HH:mm:ss"
            
            let date = Date(timeIntervalSince1970: TimeInterval(self.timestamp) / 1000)
            relativeDate = formatter.string(from: date)
        }
        return relativeDate
    }
    
}

extension Hashtag: Equatable {
    
    static func == (lhs: Hashtag, rhs: Hashtag) -> Bool {
        return lhs.name == rhs.name
    }
    
}

typealias Hashtags = [Hashtag]

extension Hashtags {

    func names() -> [String] {
        return self.map { $0.name }
    }
}

extension Mentions {
    func asHashtags() -> [Hashtag] {
        return self.filter {
            return $0.link.hasPrefix("#")
        }.map {
            return Hashtag(name: String($0.link.dropFirst()))
        }
    }
}

