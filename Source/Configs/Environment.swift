//
//  Environment.swift
//  Planetary
//
//  Created by Martin Dutra on 2/17/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation
import Secrets

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
    
    enum PlanetarySystem {
        
        static let systemPubs: [Star] = {
            Environment.value(for: "PLPlanetarySystem").split(separator: " ").map { Star(invite: String($0)) }
        }()
        
        static let communityPubs: [Star] = {
            Environment.value(for: "PLCommunities").split(separator: " ").map { Star(invite: String($0)) }
        }()
        
        static let planetaryIdentity: Identity = {
            Environment.value(for: "PLPlanetaryIdentity")
        }()
        
        static let communityAliasServers: [Room] = {
            return parseCommunityServers(environmentKey: "PLAliasServers")
        }()
    }
    enum TestNetwork {
        static let systemPubs: [Star] = {
            Environment.value(for: "PLTestNetworkPubs").split(separator: " ").map { Star(invite: String($0)) }
        }()
        
        static let communityPubs: [Star] = {
            Environment.value(for: "PLTestNetworkCommunities").split(separator: " ").map { Star(invite: String($0)) }
        }()
        
        static let communityAliasServers: [Room] = {
            parseCommunityServers(environmentKey: "PLTestAliasServers")
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
    
    private static func parseCommunityServers(environmentKey: String) -> [Room] {
        var communityAliasServers = [Room]()
        
        Environment.value(for: environmentKey).components(separatedBy: "||").forEach {
            let aliasServerComponents = $0.components(separatedBy: "::")
            let identifier = aliasServerComponents[0]
            let imageName = aliasServerComponents[2]
            guard let key = Key(rawValue: aliasServerComponents[3]),
                let token = Keys.shared.get(key: key),
                let address = MultiserverAddress(string: aliasServerComponents[1]),
                !identifier.isEmpty,
                !imageName.isEmpty
            else {
                return
            }
            communityAliasServers.append(
                Room(token: token, identifier: identifier, imageName: imageName, address: address)
            )
        }
        return communityAliasServers
    }
}
