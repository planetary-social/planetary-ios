//
//  Secrets.swift
//  
//
//  Created by Martin Dutra on 24/11/21.
//

import Logger

open class Secrets {

    public enum Key {
        case posthog
        case bugsnag
        case push
    }
    
    public static let shared = Secrets(service: SecretsServiceAdapter(bundleSecretsService: PlistService()))

    var service: SecretsService?

    public init() {
        self.service = nil
    }

    init(service: SecretsService) {
        self.service = service
    }

    open func get(key: Secrets.Key) -> String? {
        let mapper = KeyMapper()
        if let key = mapper.map(key: key) {
            return service?.get(key: key)
        } else {
            Log.fatal(.incorrectValue, "KeyMapper couldn't map a key")
            return nil
        }
    }

}
