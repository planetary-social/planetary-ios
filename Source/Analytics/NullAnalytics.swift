//
//  NullAnalytics.swift
//  FBTT
//
//  Created by Christoph on 5/22/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

class NullAnalytics: AnalyticsService {
    
    var isEnabled: Bool { return false }
    
    func identify(about: About?, network: NetworkKey) { }
    func identify(statistics: BotStatistics) { }
    func forget() { }

    func optIn() {}
    func optOut() {}
    
    func updatePushToken(pushToken: Data?) { }

    func time(event: AnalyticsEnums.Event,
              element: AnalyticsEnums.Element,
              name: AnalyticsEnums.Name.RawValue) { }
    
    func track(event: AnalyticsEnums.Event,
               element: AnalyticsEnums.Element,
               name: AnalyticsEnums.Name.RawValue,
               params:  AnalyticsEnums.Params?) {}

    func trackOnboardingStart() {}

    func trackOnboardingEnd() {}
    
    func trackBotDidPublish(_ identifier: BlobIdentifier, numberOfBytes: Int?) {}

    func trackLoad(_ identifier: BlobIdentifier) {}
    func trackDidLoad(_ identifier: BlobIdentifier) {}

    enum DidLoadBlobError: String {
        case notAvailable = "not_available"
        case emptyData = "empty_data"
        case notImageData = "not_image_data"
    }

    func trackAppDidLoad(_ identifier: BlobIdentifier, error: DidLoadBlobError? = nil) {}
}
