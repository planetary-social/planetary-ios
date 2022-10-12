//
//  Created by Christoph on 4/18/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

enum BotError: Error, LocalizedError {
    case alreadyLoggedIn
    case blobInvalidIdentifier
    case blobUnsupportedFormat
    case blobUnavailable
    case blobMaximumSizeExceeded
    case encodeFailure
    case invalidIdentity
    case notLoggedIn
    case forkProtection
    case invalidAppConfiguration
    case restoring
    case internalError
    
    // MARK: - LocalizedError
    
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
        case .forkProtection:
            return Localized.Error.cannotPublishBecauseRestoring.text
        case .invalidAppConfiguration:
            return Localized.Error.invalidAppConfiguration.text
        case .restoring:
            return Localized.Error.restoring.text
        case .internalError:
            return Localized.Error.unexpected.text
        }
    }
}
