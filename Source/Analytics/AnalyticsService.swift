//
//  AnalyticsService.swift
//  FBTT
//
//  Created by Christoph on 3/2/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

protocol AnalyticsService {

    var isEnabled: Bool { get }

    func identify(about: About?, network: NetworkKey)
    func identify(statistics: BotStatistics)
    func updatePushToken(pushToken: Data?)
    func optIn()
    func optOut()
    func forget()
    func time(event: AnalyticsEnums.Event, element: AnalyticsEnums.Element, name: AnalyticsEnums.Name.RawValue)
    func track(event: AnalyticsEnums.Event, element: AnalyticsEnums.Element, name: AnalyticsEnums.Name.RawValue, params:  AnalyticsEnums.Params?)
    
}

// MARK: Track single param

extension AnalyticsService {

    func track(event: AnalyticsEnums.Event, element: AnalyticsEnums.Element, name: AnalyticsEnums.Name.RawValue, param: String? = nil, value: String? = nil) {
        var params: AnalyticsEnums.Params = [:]
        if let param = param, let value = value { params[param] = value }
        self.track(event: event, element: element, name: name, params: params)
    }
    
}

// MARK: Lexicon
extension AnalyticsService {
    
    /// Returns an alphabetically sorted list of composited event names.  This is useful to list
    /// the potential event names that could be used in Posthog.
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
    
    /// Returns a underscored string that has merged the arguments.
    func eventName(event: AnalyticsEnums.Event, element: AnalyticsEnums.Element, name: AnalyticsEnums.Name.RawValue) -> String {
        let strings = [event.rawValue, element.rawValue, name]
        let merged = strings.joined(separator: "_")
        return merged
    }
    
}
