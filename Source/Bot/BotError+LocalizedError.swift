//
//  BotError+LocalizedError.swift
//  Planetary
//
//  Created by Martin Dutra on 4/7/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation

extension BotError: LocalizedError {
    
    var errorDescription: String? {
        switch self {
        case .alreadyLoggedIn:
            return "Already logged in"
        case .blobInvalidIdentifier:
            return "Blob invalid identifier"
        case .blobUnsupportedFormat:
            return "Blob unsupported format"
        case .blobUnavailable:
            return "Blob unavailable"
        case .blobMaximumSizeExceeded:
            return "Blob maximum size exceeded"
        case .encodeFailure:
            return "Encode failure"
        case .invalidIdentity:
            return "Invalid identity"
        case .notLoggedIn:
            return "Not logged in"
        case .notEnoughMessagesInRepo:
            return "Not enough messages in repo"
        }
    }
    
}
