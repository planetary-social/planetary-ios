//
//  PopularHashtagsAlgorithm.swift
//  Planetary
//
//  Created by Martin Dutra on 3/6/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation
import SQLite

/// This algorithm returns a list of hashtags with the most popular hashtags at the top
class PopularHashtagsAlgorithm: HashtagListStrategy {
    
    // swiftlint:disable indentation_width
    private let query = """
        SELECT DISTINCT ( channels.name ) AS channel_name,
                        Count(*)          AS message_count
        FROM   "channels",
               "channel_assignments",
               "messages"
        WHERE  "messages"."msg_id" = "channel_assignments"."msg_ref"
               AND "channels"."id" = "channel_assignments"."chan_ref"
        GROUP  BY channels.id
        ORDER  BY "message_count" DESC;
    """
    // swiftlint:enable indentation_width
    
    func fetchHashtags(connection: Connection, userId: Int64) throws -> [Hashtag] {
        try connection.prepare(query).prepareRowIterator().map { channelRow -> Hashtag in
            let name = try channelRow.get(Expression<String>("channel_name"))
            let messageCount = try channelRow.get(Expression<Int64>("message_count"))
            return Hashtag(name: name, count: messageCount)
        }
    }
}
