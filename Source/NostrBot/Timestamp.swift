import Foundation

public struct Timestamp: Codable {
    public let timestamp: Int
    
    public init(date: Date) {
        self = .init(timestamp: Int(date.timeIntervalSince1970))
    }
    
    public init(timestamp: Int) {
        self.timestamp = timestamp
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        try timestamp = container.decode(Int.self)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(timestamp)
    }
}
