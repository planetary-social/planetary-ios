import Foundation

public enum RelayMessage: Decodable {
    case event(SubscriptionId, Event)
    case notice(String)
    case other([String])
    
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        
        let messageType = try container.decode(String.self)
        
        switch messageType {
        case "EVENT":
            let subscriptionId = try container.decode(SubscriptionId.self)
            let event = try container.decode(Event.self)
            self = .event(subscriptionId, event)
        case "NOTICE":
            self = .notice(try container.decode(String.self))
        default:
            let remainingItemsCount = (container.count ?? 1) - 1
            let remainingItems = try (0..<remainingItemsCount).map { _ in try container.decode(String.self) }
            self = .other([messageType] + remainingItems)
        }
    }
    
    public init(text: String) throws {
        self = try JSONDecoder().decode(RelayMessage.self, from: text.data(using: .utf8)!)
    }
}
