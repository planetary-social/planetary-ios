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

    // MixPanel confusingly uses the negative case to indicate status
    // If MixPanel was not initialized, then the user could not have opted out.
    var isEnabled: Bool {
        let optedOut = Mixpanel.sharedInstance()?.hasOptedOutTracking()
        let enabled = !(optedOut ?? true)
        return enabled
    }

    func configure() {
        Mixpanel.sharedInstance(withToken: Environment.Mixpanel.token)
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

    /// Mixpanel allows timing between two events of the same name.  We composite the
    /// event, element and name into a single string for `track()` so we do the same thing
    /// here.  The oddity is that Mixpanel doesn't allow any additional properties with the time
    /// call, so `name` needs to be unique if multiple events, like downloading a blob, can
    /// happen at the same time.  Note that this is Mixpanel specific, and is not in the AnalyticsCore.
    func time(event: AnalyticsEnums.Event,
              element: AnalyticsEnums.Element,
              name: AnalyticsEnums.Name.RawValue)
    {
        let event = self.eventName(event: event, element: element, name: name)
        Mixpanel.sharedInstance()?.timeEvent(event)
        UserDefaults.standard.didTrack(event)
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
