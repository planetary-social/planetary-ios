//
//  Created by Christoph on 4/17/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

///
protocol ContentCodable: Codable, ContentTypeable {}

/// Shared implementation to JSON encode a model.  It's important
/// to note that JSONEncode.encode() only accepts concrete models,
/// not protocols, so ContentCodable cannot be encoded directly.
/// Instead, `self` must be cast to its concrete type first, then
/// encoded.  This is also why the func is called `encodeToData()`
/// rather than providing an implementation for `Encodable.encode()`.
extension ContentCodable {

    /// IMPORTANT!
    /// This func specifically uses an exhaustive switch.  This is to avoid
    /// new models being created and `ContentType` being modified without
    /// defining if the model can be published or not.  DO NOT simply add
    /// a `default:` case to
    func encodeToData() throws -> Data {
        switch self.type {

            // models that can be published
            case .about:    if let encodable = self as? About { return try JSONEncoder().encode(encodable) }
            case .contact:  if let encodable = self as? Contact { return try JSONEncoder().encode(encodable) }
            case .dropContentRequest: // i can re-pad this
                            if let encodable = self as? DropContentRequest // if the PR is fine (i'd love it if swift had gofmt)
                                                                       { return try JSONEncoder().encode(encodable) }
            case .pub:      if let encodable = self as? Pub { return try JSONEncoder().encode(encodable) }
            case .post:     if let encodable = self as? Post { return try JSONEncoder().encode(encodable) }
            case .vote:     if let encodable = self as? ContentVote { return try JSONEncoder().encode(encodable) }

            // models that SHOULD NOT be published
            case .address:      throw BotError.encodeFailure
            case .unknown:      throw BotError.encodeFailure
            case .unsupported:  throw BotError.encodeFailure
        }

        // likely this should have thrown already
        throw BotError.encodeFailure
    }
}
