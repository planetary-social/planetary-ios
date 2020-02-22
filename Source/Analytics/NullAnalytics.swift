//
//  NullAnalytics.swift
//  FBTT
//
//  Created by Christoph on 5/22/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

let Analytics = NullAnalytics()

class NullAnalytics: AnalyticsCore {

    var isEnabled: Bool { return false }

    func configure() {}

    func optIn() {}
    func optOut() {}

    func track(event: AnalyticsEnums.Event,
               element: AnalyticsEnums.Element,
               name: AnalyticsEnums.Name.RawValue,
               params:  AnalyticsEnums.Params?) {}

    func trackPurge(_ cache: AnalyticsEnums.Name.Cache,
                    from: (count: Int, numberOfBytes: Int),
                    to: (count: Int, numberOfBytes: Int)) {}

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
