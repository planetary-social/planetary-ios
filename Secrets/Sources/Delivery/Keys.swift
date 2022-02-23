//
//  Secrets.swift
//  
//
//  Created by Martin Dutra on 24/11/21.
//

import Logger

/// The Keys class perovides a simple key-value storage (in a .plist file) utility that
/// can be used to retrieve secrets in a secure way
public class Keys {
    
    public static let shared = Keys(service: SecretsServiceAdapter(bundleSecretsService: PlistService()))

    var service: SecretsService?
    
    init(service: SecretsService) {
        self.service = service
    }

    /// Retrieve a value associated with a given key
    ///
    /// - parameter key: The key whose value is going to be retrieved
    /// - returns: The value of the key. Returns nil if it doesn't exist or the .plist file couldn't be found
    public func get(key: Key) -> String? {
        return service?.get(key: key.rawValue)
    }

}
