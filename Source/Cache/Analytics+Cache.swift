//
//  Analytics+Cache.swift
//  Planetary
//
//  Created by Christoph on 12/5/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

extension MixpanelAnalytics {

    func trackPurge(_ cache: AnalyticsEnums.Name.Cache,
                    from: (count: Int, numberOfBytes: Int),
                    to: (count: Int, numberOfBytes: Int))
    {
        let params: AnalyticsEnums.Params = ["from_count": from.count,
                                             "from_number_of_bytes": from.numberOfBytes,
                                             "to_count": to.count,
                                             "to_number_of_bytes": to.numberOfBytes]

        self.track(event: .purge,
                   element: .cache,
                   name: cache.rawValue,
                   params: params)
    }
}
