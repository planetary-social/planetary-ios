//  Post.swift
//  FBTTUnitTests
//
//  Created by Christoph on 1/28/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

class Post: ContentCodable {

    enum CodingKeys: String, CodingKey {
        case branch
        case mentions
        case recps
        case reply
        case root 
        case text
        case type
    }

    let branch: [Identifier]?
    let mentions: [Mention]?
    let recps: [RecipientElement]?
    let reply: [Identifier: Identifier]?
    let root: MessageIdentifier?
    let text: String
    let type: ContentType
    
    /// Returns blobs extracted from the post's markdown.
    /// This is expensive to calculate so we lazy load it as an optimiation
    fileprivate(set) lazy var inlineBlobs: Blobs = {
        self.text.blobs()
    }()

    // MARK: Calculated temporal unserialized properties

    internal var _attributedString: NSMutableAttributedString?

    // MARK: Lifecycle

    /// Intended to be used when publishing a new Post from a UI.
    /// Check out NewPostViewController for an example.
    init(attributedText: NSAttributedString,
         root: MessageIdentifier? = nil,
         branches: [MessageIdentifier]? = nil) {
        // required
        self.branch = branches
        self.root = root
        self.text = attributedText.markdown
        self.type = .post

        var mentionsFromHashtags = attributedText.string.hashtags().map {
            tag in
            Mention(link: tag.string)
        }

        mentionsFromHashtags.append(contentsOf: attributedText.mentions())
        self.mentions = mentionsFromHashtags

        // unused
        self.recps = nil
        self.reply = nil
    }

    /// Intended to be used to create models in the view database or unit tests.
    init(blobs: Blobs? = nil,
         branches: [MessageIdentifier]? = nil,
         hashtags: Hashtags? = nil,
         mentions: [Mention]? = nil,
         root: MessageIdentifier? = nil,
         text: String) {
        // required
        self.branch = branches
        self.root = root
        self.text = text
        self.type = .post
        
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
        self.reply = nil
    }

    /// Intended to be used to decode a model from JSON.
    required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        branch = Post.decodeBranch(from: values)
        mentions = try? values.decode([Mention].self, forKey: .mentions)
        recps = try? values.decode([RecipientElement].self, forKey: .recps)
        reply = try? values.decode([Identifier: Identifier].self, forKey: .reply)
        root = try? values.decode(Identifier.self, forKey: .root)
        text = try values.decode(String.self, forKey: .text)
        type = try values.decode(ContentType.self, forKey: .type)
    }

    private static func decodeBranch(from values: KeyedDecodingContainer<Post.CodingKeys>) -> [Identifier]? {
        if let branch = try? values.decode(Identifier.self, forKey: .branch) {
            return [branch]
        } else {
            return try? values.decode([Identifier].self, forKey: .branch)
        }
    }
    
    /// Returns `[(Identifier, MIMEType)]` for all detected media on a post.
    func attachedMedia() -> [(Identifier, MIMEType)] {
        var attachedMedia = [(Identifier, MIMEType)]()
        
        mentions?.forEach { mention in
            guard let type = mention.type, let mimeType = MIMEType(rawValue: type) else {
                
                // switch on name extension?
                
                attachedMedia.append((mention.identity, MIMEType.unknown))
                return
            }
            attachedMedia.append((mention.identity, mimeType))
        }
        return attachedMedia
    }
}

extension Post {

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
}

struct RecipientNamedKey: Codable {
    let link: Identity
    let name: String
    
    enum CodingKeys: String, CodingKey {
        case name
        case link
    }
}

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
func getRecipientIdentities(recps: [RecipientElement]) -> [Identity] {
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

extension String {
    func getPathExtension() -> String {
        return (self as NSString).pathExtension
    }
}
