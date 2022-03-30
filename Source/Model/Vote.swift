//
//  Vote.swift
//  FBTTUnitTests
//
//  Created by Christoph on 1/28/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

/// Unlike other content models, the Vote model is actually
/// a child of Content as opposed to a flavor of it.  As such,
/// it requires special decoding via the ContentVote model.
struct Vote: Codable {
    let link: Identifier
    let value: Int
    let expression: String?
}

struct ContentVote: ContentCodable {
    
    enum CodingKeys: String, CodingKey {
        case branch
        case root
        case recps
        case vote
        case type
    }
    
    let type: ContentType
    let vote: Vote
    
    // TODO: share recps in content?
    let recps: [RecipientElement]?
    
    // TODO: share tangeling with Post
    let branch: [Identifier]?
    let root: Identifier?
    
    // parse new msgs
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        type = try values.decode(ContentType.self, forKey: .type)
        vote = try values.decode(Vote.self, forKey: .vote)

        root = try? values.decode(Identifier.self, forKey: .root)
        branch = ContentVote.decodeBranch(from: values)
        
        recps = try? values.decode([RecipientElement].self, forKey: .recps)
    }

    private static func decodeBranch(from values: KeyedDecodingContainer<ContentVote.CodingKeys>) -> [Identifier]? {
        if let branch = try? values.decode(Identifier.self, forKey: .branch) {
            return [branch]
        } else {
            return try? values.decode([Identifier].self, forKey: .branch)
        }
    }

    // create/publish
    init(link: LinkIdentifier, value: Int) {
        self.type = .vote
        
        let exp: String
        if value == 1 {
            exp = "❤️"
        } else {
            exp = "💔"
        }
        self.vote = Vote(link: link, value: value, expression: exp)
        
        self.root = nil
        self.branch = nil
        
        // TODO: constructor for PMs (should maybe also live in Content.init
        self.recps = nil
    }

    init(link: LinkIdentifier, value: Int, root: MessageIdentifier, branches: [MessageIdentifier]) {
        self.type = .vote
        
        let exp: String
        if value == 1 {
            exp = "❤️"
        } else {
            exp = "💔"
        }
        self.vote = Vote(link: link, value: value, expression: exp)

        self.root = root
        self.branch = branches
        
        // TODO: constructor for PMs (should maybe also live in Content.init
        self.recps = nil
    }
    
    init(value: Int, root: MessageIdentifier) {
        self.type = .vote
        
        let exp: String
        if value == 1 {
            exp = "❤️"
        } else {
            exp = "💔"
        }
        self.vote = Vote(link: LinkIdentifier.null, value: value, expression: exp)
        // self.link = Identity.null
        
        self.root = root
        self.branch = nil
        
        // TODO: constructor for PMs (should maybe also live in Content.init
        self.recps = nil
    }
}
