//
//  Environment.swift
//  Planetary
//
//  Created by Martin Dutra on 2/17/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation

enum Environment {
    
    enum DefaultNetwork {
        private enum Keys {
            static let name = "PLDefaultNetworkName"
            static let key = "PLDefaultNetworkKey"
            static let hmac = "PLDefaultNetworkHMAC"
        }
        static let name: String = {
            Environment.value(for: Keys.name)
        }()
        static let key: String = {
            Environment.value(for: Keys.key)
        }()
        static let hmac: String? = {
            Environment.valueIfPresent(for: Keys.hmac)
        }()
    }
    
    enum DevelopmentNetwork {
        private enum Keys {
            static let name = "PLDevelopmentNetworkName"
            static let key = "PLDevelopmentNetworkKey"
            static let hmac = "PLDevelopmentNetworkHMAC"
        }
        static let name: String = {
            Environment.value(for: Keys.name)
        }()
        static let key: String = {
            Environment.value(for: Keys.key)
        }()
        static let hmac: String = {
            Environment.value(for: Keys.hmac)
        }()
    }
    
    enum TestingNetwork {
        private enum Keys {
            static let name = "PLTestingNetworkName"
            static let key = "PLTestingNetworkKey"
            static let hmac = "PLTestingNetworkHMAC"
        }
        static let name: String = {
            Environment.value(for: Keys.name)
        }()
        static let key: String = {
            Environment.value(for: Keys.key)
        }()
        static let hmac: String = {
            Environment.value(for: Keys.hmac)
        }()
    }
    
    enum PlanetaryNetwork {
        private enum Keys {
            static let name = "PLPlanetaryNetworkName"
            static let key = "PLPlanetaryNetworkKey"
            static let hmac = "PLPlanetaryNetworkHMAC"
        }
        static let name: String = {
            Environment.value(for: Keys.name)
        }()
        static let key: String = {
            Environment.value(for: Keys.key)
        }()
        static let hmac: String = {
            Environment.value(for: Keys.hmac)
        }()
    }
    
    enum Communities {
        private enum Keys {
            static let communities = "PLCommunities"
        }
        static let stars: [Star] = {
            Environment.value(for: Keys.communities).split(separator: " ").map { Star(invite: String($0)) }
        }()
    }
    
    enum Constellation {
        private enum Keys {
            static let constellation = "PLConstellation"
        }
        static let stars: [Star] = {
            Environment.value(for: Keys.constellation).split(separator: " ").map { Star(invite: String($0)) }
        }()
    }
    
    enum PlanetarySystem {
        private enum Keys {
            static let planetarySystem = "PLPlanetarySystem"
        }
        static let planets: [Identity] = {
            Environment.value(for: Keys.planetarySystem).split(separator: " ").map { String($0) }
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
