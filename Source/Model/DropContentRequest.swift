//
//  ContentDeleteRequest.swift
//  Planetary
//
//  Created by H on 30.10.19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

class DropContentRequest: ContentCodable {
    let type: ContentType
    
    let sequence: UInt           // the sequence number on the authors feed
    let hash: MessageIdentifier  // the has of the message, as a confirmation
    
    init(sequence: UInt, hash: MessageIdentifier) {
        self.type = .dropContentRequest
        self.sequence = sequence
        self.hash = hash
    }
    
    enum CodingKeys: String, CodingKey {
        case type
        case sequence
        case hash
    }
    
    required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try values.decode(ContentType.self, forKey: .type)
        self.sequence = try values.decode(UInt.self, forKey: .sequence)
        self.hash = try values.decode(MessageIdentifier.self, forKey: .hash)
    }
}
