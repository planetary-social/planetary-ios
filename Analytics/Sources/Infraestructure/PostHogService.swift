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
        return posthog != nil
    }

    var posthog: PHGPostHog?

    init(keys: Keys = Keys.shared, middlewares: [PHGMiddleware]? = nil) {
        Log.info("Configuring PostHog...")

        guard let apiKey = keys.get(key: .posthog) else {
            return
        }

        let configuration = PHGPostHogConfiguration(apiKey: apiKey,
                                                    host: "https://app.posthog.com")

        // Record certain application events automatically!
        configuration.captureApplicationLifecycleEvents = true

        // Record screen views automatically!
        configuration.recordScreenViews = true

        configuration.middlewares = middlewares
        
        PHGPostHog.setup(with: configuration)
        
        posthog = PHGPostHog.shared()
    }

    func identify(identity: Identity) {
        posthog?.identify(identity.identifier,
                          properties: ["Network": identity.network,
                                       "$name": identity.name ?? ""])
        posthog?.enable()
    }

    func identify(statistics: Statistics) {
        // TODO: Fill
    }

    func forget() {
        posthog?.reset()
        posthog?.disable()
    }

    func track(event: String, params: [String : Any]?) {
        posthog?.capture(event, properties: params)
        UserDefaults.standard.didTrack(event)
    }

}
