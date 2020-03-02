//
//  Environment.swift
//  Planetary
//
//  Created by Martin Dutra on 2/17/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation

enum Environment {
    
    enum Mixpanel {
        private enum Keys {
            static let token = "PLMixpanelToken"
        }
        static let token: String = {
            return Environment.value(for: Keys.token)
        }()
    }
    
    enum Authy {
        private enum Keys {
            static let token = "PLAuthyToken"
        }
        static let token: String = {
            return Environment.value(for: Keys.token)
        }()
    }
    
    enum Zendesk {
        private enum Keys {
            static let appId = "PLZendeskAppId"
            static let clientId = "PLZendeskClientId"
            static let url = "PLZendeskURL"
        }
        static let appId: String = {
            return Environment.value(for: Keys.appId)
        }()
        static let clientId: String = {
            return Environment.value(for: Keys.clientId)
        }()
        static let url: String = {
            return Environment.value(for: Keys.url)
        }()
    }
    
    enum Push {
        private enum Keys {
            static let token = "PLPushToken"
            static let host = "PLPushHost"
            static let environment = "PLPushEnvironment"
        }
        static let token: String = {
            return Environment.value(for: Keys.token)
        }()
        static let host: String = {
            return Environment.value(for: Keys.host)
        }()
        static let environment: String = {
            return Environment.value(for: Keys.environment)
        }()
    }
    
    enum Pub {
        private enum Keys {
            static let token = "PLPubToken"
            static let host = "PLPubHost"
        }
        static let token: String = {
            return Environment.value(for: Keys.token)
        }()
        static let host: String = {
            return Environment.value(for: Keys.host)
        }()
    }
    
    enum Verse {
        private enum Keys {
            static let token = "PLVerseToken"
            static let host = "PLVerseHost"
            static let directoryPath = "PLVerseDirectoryPath"
        }
        static let token: String = {
            return Environment.value(for: Keys.token)
        }()
        static let host: String = {
            return Environment.value(for: Keys.host)
        }()
        static let directoryPath: String = {
            return Environment.value(for: Keys.directoryPath)
        }()
    }
    
    enum DefaultNetwork {
        private enum Keys {
            static let name = "PLDefaultNetworkName"
            static let key = "PLDefaultNetworkKey"
        }
        static let name: String = {
            return Environment.value(for: Keys.name)
        }()
        static let key: String = {
            return Environment.value(for: Keys.key)
        }()
    }
    
    enum DevelopmentNetwork {
        private enum Keys {
            static let name = "PLDevelopmentNetworkName"
            static let key = "PLDevelopmentNetworkKey"
            static let hmac = "PLDevelopmentNetworkHMAC"
        }
        static let name: String = {
            return Environment.value(for: Keys.name)
        }()
        static let key: String = {
            return Environment.value(for: Keys.key)
        }()
        static let hmac: String = {
            return Environment.value(for: Keys.hmac)
        }()
    }
    
    enum TestingNetwork {
        private enum Keys {
            static let name = "PLTestingNetworkName"
            static let key = "PLTestingNetworkKey"
            static let hmac = "PLTestingNetworkHMAC"
        }
        static let name: String = {
            return Environment.value(for: Keys.name)
        }()
        static let key: String = {
            return Environment.value(for: Keys.key)
        }()
        static let hmac: String = {
            return Environment.value(for: Keys.hmac)
        }()
    }
    
    enum PlanetaryNetwork {
        private enum Keys {
            static let name = "PLPlanetaryNetworkName"
            static let key = "PLPlanetaryNetworkKey"
            static let hmac = "PLPlanetaryNetworkHMAC"
        }
        static let name: String = {
            return Environment.value(for: Keys.name)
        }()
        static let key: String = {
            return Environment.value(for: Keys.key)
        }()
        static let hmac: String = {
            return Environment.value(for: Keys.hmac)
        }()
    }
    
    private static func value(for key: String) -> String {
        guard let value = Environment.infoDictionary[key] as? String else {
            fatalError("\(key) not set in plist")
        }
        return value
    }
    
    private static let infoDictionary: [String: Any] = {
        guard let dict = Bundle(for: AppConfiguration.self).infoDictionary else {
            fatalError("Plist file not found")
        }
        return dict
    }()
    
}
