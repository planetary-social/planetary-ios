//
//  Gathering.swift
//  Planetary
//
//  Created by Rabble on 8/20/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

// This is a messy WIP. - rabble


import Foundation

class Gathering: Codable {

    enum CodingKeys: String, CodingKey {
        case branch
        case mentions
        case recps
        case reply
        case root
        case description
        case type
    }

    let branch: [Identifier]?
    let mentions: [Mention]?
    let recps: [RecipientElement]?
    let root: MessageIdentifier?
    let description: String
    let type: ContentType
    


    // MARK: Calculated temporal unserialized properties

    internal var _attributedString: NSMutableAttributedString?

    // MARK: Lifecycle

    /// Intended to be used when publishing a new Blog Post from a UI.
    /// Check out NewPostViewController for an example.
    init(attributedText: NSAttributedString,
         root: MessageIdentifier? = nil,
         branches: [MessageIdentifier]? = nil) {
        // required
        self.branch = branches
        self.root = root
        self.description = attributedText.markdown
        self.type = .blog

        var mentionsFromHashtags = attributedText.string.hashtags().map {
            tag in
            Mention(link: tag.string)
        }

        mentionsFromHashtags.append(contentsOf: attributedText.mentions())
        self.mentions = mentionsFromHashtags

        // unused
        self.recps = nil

    }

    /// Intended to be used to create models in the view database or unit tests.
    init(blobs: Blobs? = nil,
         branches: [MessageIdentifier]? = nil,
         hashtags: Hashtags? = nil,
         mentions: [Mention]? = nil,
         root: MessageIdentifier? = nil,
         summary: String,
         title: String,
         blog: Identifier) {
        // required
        self.branch = branches
        self.root = root
        self.description = description
        
        var m: Mentions = []
        if let mentions = mentions {
            m = mentions
        }
        if let blobs = blobs {
            for b in blobs {
                m.append(b.asMention())
            }
        }
        if let tags = hashtags {
            for h in tags {
                m.append(Mention(link: h.string))
            }
        }
        // keep it optional
        self.mentions = m.count > 0 ? m : nil

        // unused
        self.recps = nil
    }

    /// Intended to be used to decode a model from JSON.
    required init(from decoder: Decoder) throws {
        let values  = try decoder.container(keyedBy: CodingKeys.self)
        //branch      = Gathering.decodeBranch(from: values)
        mentions    = try? values.decode([Mention].self, forKey: .mentions)
        recps       = try? values.decode([RecipientElement].self, forKey: .recps)
        //reply      = try? values.decode([Identifier: Identifier].self, forKey: .reply)
        root        = try? values.decode(Identifier.self, forKey: .root)
        description = try values.decode(String.self, forKey: .description)
        type        = try values.decode(ContentType.self, forKey: .type)
    }

    private static func decodeBranch(from values: KeyedDecodingContainer<Blog.CodingKeys>) -> [Identifier]? {
        if let branch = try? values.decode(Identifier.self, forKey: .branch) {
            return [branch]
        } else {
            return try? values.decode([Identifier].self, forKey: .branch)
        }
    }
}

extension Blog {

    var isRoot: Bool {
        self.root == nil
    }

    func doesMention(_ identity: Identity?) -> Bool {
        guard let identity = identity else { return false }
        return self.mentions?.contains(where: { $0.identity == identity }) ?? false
    }
}

/* code to handle both kinds of recpients:
 patchcore publishes this object instead of just the key as a string
 { link: @pubkey, name: somenick}
 
 
 handling from https://stackoverflow.com/a/49023027
*/

/*
 Re-used from Post... doesn't need to be here.
 
struct RecipientNamedKey: Codable {
    let link: Identity
    let name: String
    
    enum CodingKeys: String, CodingKey {
        case name
        case link
    }
}

enum RecipientElement: Codable {
    case namedKey(RecipientNamedKey)
    case string(Identity)
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let x = try? container.decode(Identity.self) {
            self = .string(x)
            return
        }
        if let x = try? container.decode(RecipientNamedKey.self) {
            self = .namedKey(x)
            return
        }
        throw DecodingError.typeMismatch(RecipientElement.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Wrong type for RecipientElement"))
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .namedKey(let x):
            try container.encode(x.link)
        case .string(let x):
            try container.encode(x)
        }
    }
}*/



/* TODO: there is a cleaner solution here
 tried this to get [Identity] but got the following error so I added getRecipientIdentities as a workaround
 Constrained extension must be declared on the unspecialized generic type 'Array' with constraints specified by a 'where' clause
 
 
 typealias Recipients = [RecipientElement]
 
 extension Recipients {
     func recipients() -> [Identity] {
        return getRecipientIdentities(self)
     }
 }
*/

/* already implimented in Post. func getRecipientIdentities(recps: [RecipientElement]) -> [Identity] {
    var identities: [Identity] = []
    for r in recps {
        switch r {
        case .string(let str):
            identities.append(str)
        case .namedKey(let nk):
            identities.append(nk.link)
        }
    }
    return identities
}
 */
