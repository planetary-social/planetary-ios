//
//  Analytics+Bot.swift
//  Planetary
//
//  Created by Christoph on 12/10/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

extension AnalyticsCore {

    func trackBotDidRefresh(duration: TimeInterval, error: Error? = nil) {
        let params: AnalyticsEnums.Params = [
            "duration": duration,
            "error": error.debugDescription,
        ]
        self.track(event: .did,
                   element: .bot,
                   name: AnalyticsEnums.Name.refresh.rawValue,
                   params: params)
    }

    func trackBotDidSync(duration: TimeInterval, numberOfMessages: Int) {
        let params: AnalyticsEnums.Params = ["duration": duration,
                                             "number_of_messages": numberOfMessages]
        self.track(event: .did,
                   element: .bot,
                   name: AnalyticsEnums.Name.sync.rawValue,
                   params: params)
    }
}
