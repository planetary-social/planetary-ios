//
//  Secrets.swift
//  
//
//  Created by Martin Dutra on 24/11/21.
//

import Foundation
import Logger

/// The Keys class perovides a simple key-value storage (in a .plist file) utility that
/// can be used to retrieve secrets in a secure way
public class Keys {

    /// Singleton holding a Keys instance
    ///
    /// This instance should be used in most cases, it prevents reading from the
    /// Secrets.plist file each time as it maintains its value in-memory
    public static let shared = Keys()

    var service: SecretsService?

    /// Creates an instance of the Keys class
    /// - parameter bundle: Bundle instance used for finding a Secrets.plist file
    ///
    /// Normally, the singleton should be used instead. This initializer is useful
    /// for testing only.
    public init(bundle: Bundle = .main) {
        self.service = SecretsServiceAdapter(bundle: bundle)
    }

    init(service: SecretsService) {
        self.service = service
    }

    /// Retrieve a value associated with a given key
    ///
    /// - parameter key: The key whose value is going to be retrieved
    /// - returns: The value of the key. Returns nil if it doesn't exist or the .plist file couldn't be found
    public func get(key: Key) -> String? {
        service?.get(key: key.rawValue)
    }
}
