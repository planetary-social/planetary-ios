//
//  PotHogService.swift
//  
//
//  Created by Martin Dutra on 5/9/21.
//

import Foundation
import PostHog
import Logger
import Secrets

class PostHogService: APIService {

    var isEnabled: Bool {
        return posthog?.enabled ?? false
    }

    var posthog: PHGPostHog?

    init(keys: Keys = Keys.shared, middlewares: [PHGMiddleware]? = nil) {
        Log.info("Configuring PostHog...")

        guard let apiKey = keys.get(key: .posthog) else {
            return
        }

        let configuration = PHGPostHogConfiguration(apiKey: apiKey)

        // Record certain application events automatically!
        configuration.captureApplicationLifecycleEvents = true

        // Record screen views automatically!
        configuration.recordScreenViews = true

        configuration.middlewares = middlewares

        posthog = PHGPostHog(configuration: configuration)
    }

    func identify(identity: Identity) {
        posthog?.identify(identity.identifier,
                          properties: ["Network": identity.network,
                                       "Name": identity.name ?? ""])
    }

    func optIn() {
        posthog?.enable()
    }

    func optOut() {
        posthog?.disable()
    }

    func forget() {
        posthog?.reset()
    }

    func track(event: String, params: [String: Any]?) {
        posthog?.capture(event, properties: params)
    }

}
