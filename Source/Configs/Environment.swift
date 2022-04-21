//
//  Environment.swift
//  Planetary
//
//  Created by Martin Dutra on 2/17/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation

struct Environment {
    
    struct Networks {
        
        static let mainNet = SSBNetwork(
            name: value(for: "PLDefaultNetworkName"),
            key: NetworkKey(base64: value(for: "PLDefaultNetworkKey"))!,
            hmac: nil
        )
        
        static let test = SSBNetwork(
            name: value(for: "PLTestingNetworkName"),
            key: NetworkKey(base64: value(for: "PLTestingNetworkKey"))!,
            hmac: HMACKey(base64: value(for: "PLTestingNetworkHMAC"))!
        )
    }
    
    enum Communities {
        private enum Keys {
            static let communities = "PLCommunities"
        }
        static let stars: [Star] = {
            Environment.value(for: Keys.communities).split(separator: " ").map { Star(invite: String($0)) }
        }()
    }
    
    enum PlanetarySystem {
        private enum Keys {
            static let planetarySystem = "PLPlanetarySystem"
        }
        
        static let pubInvitations: [Star] = {
            Environment.value(for: Keys.planetarySystem).split(separator: " ").map { Star(invite: String($0)) }
        }()
    }
    
    enum TestNetwork {
        
        static let pubs: [Star] = {
            Environment.value(for: "PLTestNetworkPubs").split(separator: " ").map { Star(invite: String($0)) }
        }()
    }
    
    private static func value(for key: String) -> String {
        guard let value = Environment.infoDictionary[key] as? String else {
            fatalError("\(key) not set in plist")
        }
        return value
    }
    
    private static func valueIfPresent(for key: String) -> String? {
        if let value = Environment.infoDictionary[key] as? String, !value.isEmpty {
            return value
        }
        return nil
    }
    
    private static let infoDictionary: [String: Any] = {
        guard let dict = Bundle.current.infoDictionary else {
            fatalError("Plist file not found")
        }
        return dict
    }()
}
