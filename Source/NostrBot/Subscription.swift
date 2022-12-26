import Foundation
import CryptoKit

public typealias SubscriptionId = String

public struct Subscription: Encodable {
    public let id: SubscriptionId
    public let filters: [EventFilter]
    
    public init(filters: [EventFilter], id: SubscriptionId = UUID().uuidString) {
        self.filters = filters
        self.id = id
    }
}
