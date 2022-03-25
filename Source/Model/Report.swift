//
//  Report.swift
//  Planetary
//
//  Created by Martin Dutra on 8/3/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation

/**
 A Report is an object that encapsulates a notification of some kind: somebody liked your post,
 somebody followed you etc.
 */
struct Report {
    
    /// Identity that received this report
    var authorIdentity: Identity
    
    /// Identifier of the message that generated this report
    var messageIdentifier: MessageIdentifier
    
    /// Kind of report (follow, like, etc)
    var reportType: ReportType
    
    /// Time of report creation (for sorting purposes)
    var createdAt: Date
    
    /// Message that generated this report
    var keyValue: KeyValue
}

enum ReportType: String {
    case feedFollowed = "feed_followed"
    case postReplied = "post_replied"
    case feedMentioned = "feed_mentioned"
    case messageLiked = "message_liked"
}
