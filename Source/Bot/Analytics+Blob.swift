//
//  Analytics+Blob.swift
//  Planetary
//
//  Created by Christoph on 12/2/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

extension MixpanelAnalytics {

    func trackLoad(_ identifier: BlobIdentifier) {
        self.time(event: .load, element: .blob, name: identifier)
    }

    func trackDidLoad(_ identifier: BlobIdentifier) {
        self.track(event: .load, element: .blob, name: identifier)
    }
    

    func trackBotDidPublish(_ identifier: BlobIdentifier, numberOfBytes: Int? = nil) {
        var params: AnalyticsEnums.Params = ["identifier": identifier]
        if let numberOfBytes = numberOfBytes { params["number_of_bytes"] = numberOfBytes }
        self.track(event: .did,
                   element: .bot,
                   name: AnalyticsEnums.Name.publishBlob.rawValue,
                   params: params)
    }

    enum DidLoadBlobError: String {
        case notAvailable = "not_available"
        case emptyData = "empty_data"
        case notImageData = "not_image_data"
    }

    func trackAppDidLoad(_ identifier: BlobIdentifier, error: DidLoadBlobError? = nil) {
        var params: AnalyticsEnums.Params = ["identifier": identifier]
        if let error = error { params["error"] = error.rawValue }
        self.track(event: .did,
                   element: .app,
                   name: AnalyticsEnums.Name.loadBlob.rawValue,
                   params: params)
    }
    
}
