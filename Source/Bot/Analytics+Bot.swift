//
//  Analytics+Bot.swift
//  Planetary
//
//  Created by Christoph on 12/10/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

extension MixpanelAnalytics {

    func trackBotRefresh() {
        self.time(event: .did, element: .bot, name: AnalyticsEnums.Name.refresh.rawValue)
    }
    
    func trackBotDidRefresh(load: RefreshLoad, duration: TimeInterval, error: Error? = nil) {
        let params: AnalyticsEnums.Params = [
            "load": load.rawValue,
            "duration": duration,
            "error": error.debugDescription
        ]
        self.track(event: .did,
                   element: .bot,
                   name: AnalyticsEnums.Name.refresh.rawValue,
                   params: params)
    }

    func trackBotSync() {
        self.time(event: .did, element: .bot, name: AnalyticsEnums.Name.sync.rawValue)
    }
    
    func trackBotDidSync(duration: TimeInterval, numberOfMessages: Int, error: Error? = nil) {
        let params: AnalyticsEnums.Params = ["duration": duration,
                                             "number_of_messages": numberOfMessages]
        self.track(event: .did,
                   element: .bot,
                   name: AnalyticsEnums.Name.sync.rawValue,
                   params: params)
    }
}
