//
//  Content.swift
//  FBTT
//
//  Created by Christoph on 1/22/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

struct Content: Codable {

    /// Used to when decoding has encountered a JSON blob
    /// that does not contain a 'type' field.
    static let invalidJSON = "Invalid JSON"

    /// This key can only be used for decoding.
    /// Content should never be encoded directly.
    enum CodingKeys: String, CodingKey {
        case type
    }

    // required type
    // if decoding fails type = .unsupported
    // and exception will have string from decode failure
    let type: ContentType
    let typeString: String
    let typeException: String?

    // supported content
    var contentException: String?
    var about: About?
    var address: Address?
    var pub: Pub?
    var contact: Contact?
    var dropContentRequest: DropContentRequest?
    var post: Post?
    var vote: ContentVote?
    var roomAliasAnnouncement: RoomAliasAnnouncement?

    init(from post: Post) {
        self.type = .post
        self.typeString = "post"
        self.typeException = nil
        self.post = post
    }
    
    init(from vote: ContentVote) {
        self.type = .vote
        self.typeString = "vote"
        self.typeException = nil
        self.vote = vote
    }

    init(from contact: Contact) {
        self.type = .contact
        self.typeString = "contact"
        self.typeException = nil
        self.contact = contact
    }
    
    init(from about: About) {
        self.type = .about
        self.typeString = "about"
        self.typeException = nil
        self.about = about
    }
    
    init(from pub: Pub) {
        self.type = .pub
        self.typeString = "pub"
        self.typeException = nil
        self.pub = pub
    }
    
    init(from roomAliasAnnouncement: RoomAliasAnnouncement) {
        self.type = .roomAliasAnnouncement
        self.typeString = "room/alias"
        self.typeException = nil
        self.roomAliasAnnouncement = roomAliasAnnouncement
    }

    /// The first responsibility of this decoder is to ensure that
    /// it never throws even when the supplied data does not contain
    /// a `type` field.  `typeString` and `typeException` will be
    /// populated with detail regarding why decoding failed.  `type`
    /// will then be set to `.unsupported` and upper layers can choose
    /// how to handle this.  If `type` is successfully decoded, then
    /// decoder will be used to supply one of the supported types.
    init(from decoder: Decoder) throws {

        var values: KeyedDecodingContainer<Content.CodingKeys>
        var typeString = Content.invalidJSON
        var type = ContentType.unsupported
        var exception: String?

        // the decoder order is important here
        // values must be done first, and non-JSON will throw it
        // typeString is next so we can capture the decode intent
        // type is last and will throw if not a known ContentType
        do {
            values = try decoder.container(keyedBy: CodingKeys.self)
            typeString = try values.decode(String.self, forKey: .type)
            type = try values.decode(ContentType.self, forKey: .type)
        } catch DecodingError.typeMismatch(_, let ctx) {
            // most likely a private message (opaque string without a type field)
            self.type = .unknown
            self.typeString = "xxx-encrypted"
            self.typeException = ctx.debugDescription
            return
        } catch DecodingError.dataCorrupted(let ctx) {
            exception = ctx.debugDescription
        } catch {
            // most likely unhandled type (like git-update or npm-packages)
            exception = error.localizedDescription
        }
        // let properties can only be initialized once
        // so the results of all the trys, which can fail
        // at different spots are copied in a single pass
        self.type = type
        self.typeException = exception
        self.typeString = typeString
        self.decodeByContentType(decoder)
    }

    /// Uses the decoder to create instances based on `self.type`.
    /// If the type is `.unsupported`, then no work is done.
    /// If the type is valid, but the decoding fails, `contentException`
    /// will contain the reason why.  Ideally `type` would be updated
    /// to `.unsupported`, however that field is not mutable.
    private mutating func decodeByContentType(_ decoder: Decoder) {
        do {
            switch self.type {
            case .about: self.about = try About(from: decoder)
            case .address: self.address = try Address(from: decoder)
            case .contact: self.contact = try Contact(from: decoder)
            case .dropContentRequest: self.dropContentRequest = try DropContentRequest(from: decoder)
            case .pub: self.pub = try Pub(from: decoder)
            case .post: self.post = try Post(from: decoder)
            case .vote: self.vote = try ContentVote(from: decoder)
            case .roomAliasAnnouncement: self.roomAliasAnnouncement = try RoomAliasAnnouncement(from: decoder)
            case .unknown, .unsupported: ()
            }
        } catch {
            self.contentException = error.localizedDescription
        }
    }

    /// Computed property indicating if the inner model failed
    /// decoding despite having a valid `ContentType`.  This is
    /// useful in identifying content that we should be able to
    /// display, but cannot for some reason.
    var isValid: Bool {
        self.type != .unsupported && self.contentException == nil
    }

    /// Various validators useful to assert an expected type.
    var isAbout: Bool { self.isValid && self.type == .about && self.about != nil }
    var isAddress: Bool { self.isValid && self.type == .address && self.address != nil }
    var isContact: Bool { self.isValid && self.type == .contact && self.contact != nil }
    var isPost: Bool { self.isValid && self.type == .post && self.post != nil }
    var isVote: Bool { self.isValid && self.type == .vote && self.vote != nil }
    
    var codableContent: ContentCodable? {
        switch type {
        case .about: return about
        case .address: return address
        case .contact: return contact
        case .dropContentRequest: return dropContentRequest
        case .pub: return pub
        case .post: return post
        case .vote: return vote
        case .roomAliasAnnouncement: return roomAliasAnnouncement
        case .unknown, .unsupported: return nil
        }
    }
}

// TODO it seems valuable to perform operations on [Content]
// that returns bunches of object like [About] or [Vote]
