//
//  Created by Christoph on 4/18/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

enum BotError: Error {
    case alreadyLoggedIn
    case blobInvalidIdentifier
    case blobUnsupportedFormat
    case blobUnavailable
    case blobMaximumSizeExceeded
    case encodeFailure
    case invalidIdentity
    case notLoggedIn
    case notEnoughMessagesInRepo
}
