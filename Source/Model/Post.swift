//  Post.swift
//  FBTTUnitTests
//
//  Created by Christoph on 1/28/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

final class Post: ContentCodable, Sendable {

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

    // MARK: Lifecycle

    /// Intended to be used when publishing a new Post from a UI.
    /// Check out NewPostViewController for an example.
    init(
        attributedText: NSAttributedString,
        root: MessageIdentifier? = nil,
        branches: [MessageIdentifier]? = nil
    ) {
        // required
        self.branch = branches
        self.root = root
        self.text = attributedText.markdown
        self.type = .post

        var mentionsFromHashtags = attributedText.string.hashtags().map { hashtag in
            Mention(link: hashtag.string)
        }

        mentionsFromHashtags.append(contentsOf: attributedText.mentions())
        self.mentions = mentionsFromHashtags

        // unused
        self.recps = nil
        self.reply = nil
    }

    /// Intended to be used when publishing a new Post from a UI.
    /// Check out PreviewView for an example.
    init(text: String, root: MessageIdentifier? = nil, branches: [MessageIdentifier]? = nil) {
        self.branch = branches
        self.root = root
        self.text = text
        self.type = .post

        let attributed = text.parseMarkdown()
        var mentions = [Mention]()
        for attributedRun in attributed.runs {
            if let link = attributedRun.attributes.link ?? attributedRun.attributes.imageURL {
                let name = String(attributed[attributedRun.range].characters)
                if link.scheme == URL.planetaryScheme {
                    let path = String(link.path.dropFirst())
                    if path.isValidIdentifier || path.isHashtag {
                        mentions.append(Mention(link: path, name: name))
                    }
                }
            }
        }
        self.mentions = mentions

        // unused
        self.recps = nil
        self.reply = nil
    }

    /// Intended to be used to create models in the view database or unit tests.
    init(
        blobs: Blobs? = nil,
        branches: [MessageIdentifier]? = nil,
        hashtags: Hashtags? = nil,
        mentions: [Mention]? = nil,
        root: MessageIdentifier? = nil,
        text: String
    ) {
        // required
        self.branch = branches
        self.root = root
        self.text = text
        self.type = .post
        
        var mention: Mentions = []
        if let mentions = mentions {
            mention = mentions
        }
        if let blobs = blobs {
            for blob in blobs {
                mention.append(blob.asMention())
            }
        }
        if let tags = hashtags {
            for hashtag in tags {
                mention.append(Mention(link: hashtag.string))
            }
        }
        // keep it optional
        self.mentions = mention.count > 0 ? mention : nil

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
}

extension Post {

    var isRoot: Bool {
        self.root == nil
    }

    /// Returns true if the post is only a markdown-formatted text
    var isTextOnly: Bool {
        anyBlobs.isEmpty
    }

    /// Returns true if the post is only a gallery of blobs
    var isBlobOnly: Bool {
        text.withoutGallery().withoutSpacesOrNewlines.isEmpty
    }

    func doesMention(_ identity: Identity?) -> Bool {
        guard let identity = identity else { return false }
        return self.mentions?.contains(where: { $0.identity == identity }) ?? false
    }
}

enum RecipientElement: Codable {
    case namedKey(RecipientNamedKey)
    case string(Identity)
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let identity = try? container.decode(Identity.self) {
            self = .string(identity)
            return
        }
        if let namedKey = try? container.decode(RecipientNamedKey.self) {
            self = .namedKey(namedKey)
            return
        }
        throw DecodingError.typeMismatch(
            RecipientElement.self,
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Wrong type for RecipientElement"
            )
        )
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .namedKey(let namedKey):
            try container.encode(namedKey.link)
        case .string(let identity):
            try container.encode(identity)
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

func getRecipientIdentities(recps: [RecipientElement]) -> [Identity] {
    var identities: [Identity] = []
    for recipient in recps {
        switch recipient {
        case .string(let identity):
            identities.append(identity)
        case .namedKey(let namedKey):
            identities.append(namedKey.link)
        }
    }
    return identities
}
