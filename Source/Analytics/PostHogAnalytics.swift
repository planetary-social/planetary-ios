//
//  PostHog.swift
//  Planetary
//
//  Created by Rabble on 12/18/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation
import PostHog
import Logger
import Secrets

class PostHogAnalytics: AnalyticsService {
    
    var isEnabled: Bool {
        return true
    }
    
    //var posthog: PHGPostHog
    var posthog: PHGPostHog? = nil
    
    init() {
        Log.info("Configuring PostHog...")
        guard let apiKey = Keys.shared.get(key: .posthog) else {
            return
        }
        let host = "https://app.posthog.com"
        let configuration = PHGPostHogConfiguration(apiKey: apiKey, host: host)
        configuration.captureApplicationLifecycleEvents = true; // Record certain application events automatically!
        configuration.recordScreenViews = true; // Record screen views automatically!

        PHGPostHog.setup(with: configuration)
        self.posthog = PHGPostHog.shared()!
    }
    
    func identify(about: About?, network: NetworkKey) {
        if let about = about {
            posthog?.identify(about.identity,
                      properties: ["Network": network.name, "$name": about.name ?? ""])
        }
    }

    func identify(statistics: BotStatistics) {
        var params: [String: Any] = [:]

        if let lastSyncDate = statistics.lastSyncDate {
            params["Last Sync"] = lastSyncDate
        }

        if let lastRefreshDate = statistics.lastRefreshDate {
            params["Last Refresh"] = lastRefreshDate
        }

        if statistics.repo.feedCount != -1 {
            params["Feed Count"] = statistics.repo.feedCount
            params["Message Count"] = statistics.repo.messageCount
            params["Published Message Count"] = statistics.repo.numberOfPublishedMessages
        }

        if statistics.db.lastReceivedMessage != -3 {
            let lastRxSeq = statistics.db.lastReceivedMessage
            if statistics.repo.feedCount != -1 {
                let diff = statistics.repo.messageCount - 1 - lastRxSeq
                params["Message Diff"] = diff
            }
        }
    }
    
    func updatePushToken(pushToken: Data?) {
        if let pushToken = pushToken {
            //Mixpanel.sharedInstance()?.people.addPushDeviceToken(pushToken)
        } else {
            //Mixpanel.sharedInstance()?.people.removeAllPushDeviceTokens()
        }
    }
    
    func forget() {
        posthog?.reset()
    }

    func optIn() {
        //Mixpanel.shsaredInstance()?.optInTracking()
    }

    func optOut() {
        //Mixpanel.sharedInstance()?.optOutTracking()
    }

    func track(event eventEnum: AnalyticsEnums.Event,
               element elementEnum: AnalyticsEnums.Element,
               name: AnalyticsEnums.Name.RawValue,
               params: AnalyticsEnums.Params? = nil) {
        
        let event = String(eventEnum.rawValue)
        let element = String(elementEnum.rawValue)
        //let name = String(name.rawValue)
        
        posthog?.capture("did", properties: ["element": element, "name": name, "params": params])
        UserDefaults.standard.didTrack(event)
        //self.posthog.flush()
    }

    func time(event: AnalyticsEnums.Event,
              element: AnalyticsEnums.Element,
              name: AnalyticsEnums.Name.RawValue)
    {
        //let event = self.eventName(event: event, element: element, name: name)
        //Mixpanel.sharedInstance()?.timeEvent(event)
    }
    

}
