//
//  About.swift
//  FBTTUnitTests
//
//  Created by Christoph on 1/28/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

/// It's important to note that the About model is not specifically
/// referring to human profiles.  Instead if is metadata about a specific
/// Identifier.  A good example is the hashtag feature.  A Tag model is
/// published to generate a Identifier, but without a name.  So, an About
/// is published referencing the tag identifier and supplying a name.
struct About: ContentCodable, Equatable {

    enum CodingKeys: String, CodingKey {
        case about
        case description
        case image
        case name
        case shortcode
        case type
        case publicWebHosting
    }

    let about: Identity
    let description: String?
    let image: ImageMetadata?
    let name: String?
    let shortcode: String?
    let type: ContentType
    let publicWebHosting: Bool?

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        description = try? values.decode(String.self, forKey: .description)
        about = try values.decode(Identifier.self, forKey: .about)
        image = About.decodeImage(from: values)
        name = try? values.decode(String.self, forKey: .name)
        shortcode = try? values.decode(String.self, forKey: .shortcode)
        type = try values.decode(ContentType.self, forKey: .type)
        publicWebHosting = try? values.decode(Bool.self, forKey: .publicWebHosting)
    }

    init() {
        self.init(about: Identity.null)
    }

    init(about: Identity) {
        self.type = .about
        self.about = about
        self.description = nil
        self.image = nil
        self.name = nil
        self.shortcode = nil
        self.publicWebHosting = nil
    }

    init(about: Identity, name: String) {
        self.type = .about
        self.about = about
        self.description = nil
        self.image = nil
        self.name = name
        self.shortcode = nil
        self.publicWebHosting = nil
    }

    init(about: Identity, descr: String) {
        self.type = .about
        self.about = about
        self.description = descr
        self.name = nil
        self.image = nil
        self.shortcode = nil
        self.publicWebHosting = nil
    }
    
    init(about: Identity, publicWebHosting: Bool) {
        self.type = .about
        self.about = about
        self.description = nil
        self.name = nil
        self.image = nil
        self.shortcode = nil
        self.publicWebHosting = publicWebHosting
    }

    init(about: Identity, image: BlobIdentifier) {
        self.type = .about
        self.about = about
        self.description = nil
        self.image = ImageMetadata(link: image)
        self.name = nil
        self.shortcode = nil
        self.publicWebHosting = nil
    }

    init(
        about: Identity,
        name: String?,
        description: String?,
        imageLink: BlobIdentifier?,
        publicWebHosting: Bool? = nil
    ) {
        self.type = .about
        self.about = about
        self.description = description
        self.image = ImageMetadata(link: imageLink)
        self.name = name
        self.shortcode = nil
        self.publicWebHosting = publicWebHosting
    }

    init(identity: Identity, name: String?, description: String?, image: ImageMetadata?, publicWebHosting: Bool?) {
        self.type = .about
        self.about = identity
        self.description = description
        self.image = image
        self.name = name
        self.shortcode = nil
        self.publicWebHosting = publicWebHosting
    }

    private static func decodeImage(from values: KeyedDecodingContainer<About.CodingKeys>) -> ImageMetadata? {
        if let identifier = try? values.decode(Identifier.self, forKey: .image) {
            return ImageMetadata(link: identifier)
        } else {
            return try? values.decode(ImageMetadata.self, forKey: .image)
        }
    }

    func mutatedCopy(
        identity: Identity? = nil,
        name: String? = nil,
        description: String? = nil,
        image: ImageMetadata? = nil,
        publicWebHosting: Bool? = nil
    ) -> About {
        About(
            identity: identity ?? self.identity,
            name: name ?? self.name,
            description: description ?? self.description,
            image: image ?? self.image,
            publicWebHosting: publicWebHosting ?? self.publicWebHosting
        )
    }
}

extension About {

    var identity: Identity {
        self.about
    }

    var nameOrIdentity: String {
        self.name?.trimmedForSingleLine ?? self.identity
    }

    // this is not performant, need to cache md results (MD: this should be removed after we stop using AboutView)
    var attributedDescription: NSMutableAttributedString {
        NSMutableAttributedString(attributedString: self.description?.decodeMarkdown() ?? NSAttributedString())
    }

    var mention: Mention {
        let mention = Mention(link: self.identity, name: self.nameOrIdentity)
        return mention
    }

    func contains(_ string: String) -> Bool {
        if let name = self.name, name.localizedCaseInsensitiveContains(string) { return true }
        if let name = self.name?.withoutSpaces, name.localizedCaseInsensitiveContains(string) { return true }
        if let code = self.shortcode, code.localizedCaseInsensitiveContains(string) { return true }
        return false
    }
}

extension About: Comparable {

    static func < (lhs: About, rhs: About) -> Bool {
        if let lhs = lhs.name, let rhs = rhs.name {
            return lhs.compare(rhs, options: .caseInsensitive) == .orderedAscending
        }
        if lhs.name == nil, rhs.name == nil {
            return lhs.identity < rhs.identity
        }
        return rhs.name == nil
    }

    static func == (lhs: About, rhs: About) -> Bool {
        lhs.identity == rhs.identity &&
        lhs.name == rhs.name &&
        lhs.description == rhs.description &&
        lhs.image == rhs.image
    }
}

extension About: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(self.identity)
    }
}
