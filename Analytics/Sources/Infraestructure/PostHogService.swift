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
        posthog?.enabled ?? false
    }

    var posthog: PHGPostHog?

    init(keys: Keys = Keys.shared, middlewares: [PHGMiddleware]? = nil) {
        Log.info("Configuring PostHog...")

        guard let apiKey = keys.get(key: .posthog) else {
            return
        }

        let configuration = PHGPostHogConfiguration(apiKey: apiKey)

        // Disable tracking events automatically as we track them manually
        // In addition, PostHog doesn't work well with these swizzle functions
        // and an instance of PHGPosthog because they use the sharedInstance
        configuration.captureApplicationLifecycleEvents = false
        configuration.recordScreenViews = false
        configuration.capturePushNotifications = false
        configuration.captureInAppPurchases = false
        configuration.captureDeepLinks = false

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
        posthog?.flush()
    }

    func optOut() {
        posthog?.flush()
        posthog?.disable()
    }

    func forget() {
        posthog?.reset()
    }

    func track(event: String, params: [String: Any]?) {
        posthog?.capture(event, properties: params)
    }
}
