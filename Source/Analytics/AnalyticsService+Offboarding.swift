//
//  AnalyticsService+Offboarding.swift
//  Planetary
//
//  Created by Christoph on 12/12/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

extension AnalyticsService {

    func trackOffboardingStart() {
        self.time(event: .did, element: .app, name: AnalyticsEnums.Name.offboarding.rawValue)
    }

    func trackOffboardingEnd() {
        self.track(event: .did, element: .app, name: AnalyticsEnums.Name.offboarding.rawValue)
    }
}
