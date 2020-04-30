//
//  MixpanelAnalytics.swift
//  FBTT
//
//  Created by Christoph on 3/2/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import Mixpanel

let Analytics = MixpanelAnalytics()

class MixpanelAnalytics: AnalyticsCore {
    
    private var configured: Bool = false

    // MixPanel confusingly uses the negative case to indicate status
    // If MixPanel was not initialized, then the user could not have opted out.
    var isEnabled: Bool {
        guard configured else {
            return false
        }
        let optedOut = Mixpanel.sharedInstance()?.hasOptedOutTracking()
        let enabled = !(optedOut ?? true)
        return enabled
    }

    func configure() {
        guard let token = Environment.Mixpanel.token else {
            configured = false
            return
        }
        Log.info("Configuring Mixpanel...")
        Mixpanel.sharedInstance(withToken: token)
        configured = true
    }
    
    func identify(about: About?, network: NetworkKey) {
        if let about = about, configured {
            Mixpanel.sharedInstance()?.identify(about.identity)
            let properties = ["Network": network.name,
                              "$name": about.name ?? ""]
            Mixpanel.sharedInstance()?.people.set(properties)
        }
    }
    
    func updatePushToken(pushToken: Data?) {
        guard configured else {
            return
        }
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
        guard configured else {
            return
        }
        Mixpanel.sharedInstance()?.optInTracking()
    }

    func optOut() {
        guard configured else {
            return
        }
        Mixpanel.sharedInstance()?.optOutTracking()
    }

    func track(event: AnalyticsEnums.Event,
               element: AnalyticsEnums.Element,
               name: AnalyticsEnums.Name.RawValue,
               params:  AnalyticsEnums.Params? = nil)
    {
        guard configured else {
            return
        }
        let event = self.eventName(event: event, element: element, name: name)
        let params = self.compatibleParams(params: params)
        Mixpanel.sharedInstance()?.track(event, properties: params)
        UserDefaults.standard.didTrack(event)
    }

    func time(event: AnalyticsEnums.Event,
              element: AnalyticsEnums.Element,
              name: AnalyticsEnums.Name.RawValue)
    {
        guard configured else {
            return
        }
        let event = self.eventName(event: event, element: element, name: name)
        Mixpanel.sharedInstance()?.timeEvent(event)
    }

    // MARK: Lexicon

    /// Returns an alphabetically sorted list of composited event names.  This is useful to list
    /// the potential event names that could be used in Mixpanel.
    func lexicon() -> [String] {
        var strings: [String] = []
        for event in AnalyticsEnums.Event.allCases {
            for element in AnalyticsEnums.Element.allCases {
                for name in AnalyticsEnums.Name.allCases {
                    let string = self.eventName(event: event, element: element, name: name.rawValue)
                    strings += [string]
                }
            }
        }
        return strings
    }
}

fileprivate extension MixpanelAnalytics {

    /// Returns a underscored string that has merged the arguments.
    private func eventName(event: AnalyticsEnums.Event,
                           element: AnalyticsEnums.Element,
                           name: AnalyticsEnums.Name.RawValue) -> String
    {
        let strings = [event.rawValue, element.rawValue, name]
        let merged = strings.joined(separator: "_")
        return merged
    }

    /// Transforms the AnalyticsEnum.Params dictionary into a Mixpanel
    /// compatible [String: Any] dictionary.
    private func compatibleParams(params: AnalyticsEnums.Params?) -> [String: Any]? {
        guard let params = params, params.isEmpty == false else { return nil }
        let keys = params.keys.map { $0 }
        let stringAnyParams = Dictionary(uniqueKeysWithValues: zip(keys, params.values))
        return stringAnyParams
    }
}
