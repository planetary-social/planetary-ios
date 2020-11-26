//
//  MixpanelAnalytics.swift
//  FBTT
//
//  Created by Christoph on 3/2/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import Mixpanel
import Keys

class MixpanelAnalytics: AnalyticsService {

    // MixPanel confusingly uses the negative case to indicate status
    // If MixPanel was not initialized, then the user could not have opted out.
    var isEnabled: Bool {
        let optedOut = Mixpanel.sharedInstance()?.hasOptedOutTracking()
        let enabled = !(optedOut ?? true)
        return enabled
    }
    
    init() {
        let keys = PlanetaryKeys()
        Log.info("Configuring Mixpanel...")
        Mixpanel.sharedInstance(withToken: keys.mixpanelAnalyticsToken)
    }
    
    func identify(about: About?, network: NetworkKey) {
        if let about = about {
            Mixpanel.sharedInstance()?.identify(about.identity)
            let properties = ["Network": network.name,
                              "$name": about.name ?? ""]
            Mixpanel.sharedInstance()?.people.set(properties)
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
        
        Mixpanel.sharedInstance()?.people.set(params)
    }
    
    func updatePushToken(pushToken: Data?) {
        if let pushToken = pushToken {
            Mixpanel.sharedInstance()?.people.addPushDeviceToken(pushToken)
        } else {
            Mixpanel.sharedInstance()?.people.removeAllPushDeviceTokens()
        }
    }
    
    func forget() {
        Mixpanel.sharedInstance()?.reset()
    }

    func optIn() {
        Mixpanel.sharedInstance()?.optInTracking()
    }

    func optOut() {
        Mixpanel.sharedInstance()?.optOutTracking()
    }

    func track(event: AnalyticsEnums.Event,
               element: AnalyticsEnums.Element,
               name: AnalyticsEnums.Name.RawValue,
               params:  AnalyticsEnums.Params? = nil)
    {
        let event = self.eventName(event: event, element: element, name: name)
        let params = self.compatibleParams(params: params)
        Mixpanel.sharedInstance()?.track(event, properties: params)
        UserDefaults.standard.didTrack(event)
    }

    func time(event: AnalyticsEnums.Event,
              element: AnalyticsEnums.Element,
              name: AnalyticsEnums.Name.RawValue)
    {
        let event = self.eventName(event: event, element: element, name: name)
        Mixpanel.sharedInstance()?.timeEvent(event)
    }

}

fileprivate extension MixpanelAnalytics {

    /// Transforms the AnalyticsEnum.Params dictionary into a Mixpanel
    /// compatible [String: Any] dictionary.
    private func compatibleParams(params: AnalyticsEnums.Params?) -> [String: Any]? {
        guard let params = params, params.isEmpty == false else { return nil }
        let keys = params.keys.map { $0 }
        let stringAnyParams = Dictionary(uniqueKeysWithValues: zip(keys, params.values))
        return stringAnyParams
    }
}
