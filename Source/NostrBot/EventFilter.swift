import Foundation

public struct EventFilter: Encodable {
    public let ids: [EventId]?
    public let authors: [String]?
    public let eventKinds: [EventKind]?
    public let eventTags: [String]?
    public let pubKeyTags: [String]?
    public let since: Timestamp?
    public let until: Timestamp?
    public let limit: Int?
    
    private enum CodingKeys: String, CodingKey {
        case ids
        case authors
        case eventKinds = "kinds"
        case eventTags = "#e"
        case pubKeyTags = "#p"
        case since
        case until
        case limit
    }
    
    public init(
        ids: [EventId]? = nil,
        authors: [String]? = nil,
        eventKinds: [EventKind]? = nil,
        eventTags: [String]? = nil,
        pubKeyTags: [String]? = nil,
        since: Timestamp? = nil,
        until: Timestamp? =  nil,
        limit: Int? = nil
    ) {
        self.ids = ids
        self.authors = authors
        self.eventKinds = eventKinds
        self.eventTags = eventTags
        self.pubKeyTags = pubKeyTags
        self.since = since
        self.until = until
        self.limit = limit
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(ids, forKey: .ids)
        try container.encodeIfPresent(authors, forKey: .authors)
        try container.encodeIfPresent(eventKinds, forKey: .eventKinds)
        try container.encodeIfPresent(eventTags, forKey: .eventTags)
        try container.encodeIfPresent(pubKeyTags, forKey: .pubKeyTags)
        try container.encodeIfPresent(since, forKey: .since)
        try container.encodeIfPresent(until, forKey: .until)
        try container.encodeIfPresent(limit, forKey: .limit)
    }
}
