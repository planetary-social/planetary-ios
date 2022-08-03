//
//  ViewDatabaseError+LocalizedError.swift
//  Planetary
//
//  Created by Martin Dutra on 4/7/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation

extension ViewDatabaseError: LocalizedError {
    
    var errorDescription: String? {
        switch self {
        case .notOpen:
            return "Not open"
        case .alreadyOpen:
            return "Already open"
        case .unknownMessage(let messageIdentifier):
            return "Unknown message: \(messageIdentifier)"
        case .unknownAuthor(let identifier):
            return "Unknown author: \(identifier)"
        case .unknownHashtag(let hashtag):
            return "There are no messages with the hashtag #\(hashtag) in your network."
        case .unknownReferenceID(let referenceId):
            return "Unknown reference id: \(referenceId)"
        case .unexpectedContentType(let contentType):
            return "Unexpected content type: \(contentType)"
        case .unknownTable(let table):
            return "Unknown table: \(table)"
        case .unhandledContentType(let contentType):
            return "Unhandled content type: \(contentType)"
        case .messageConstraintViolation(let identity, let sqlError):
            return "Message constraint violation: \(identity), \(sqlError)"
        case .invalidAddress(let address):
            return "Invalid multiserver address: \(address)"
        }
    }
}
