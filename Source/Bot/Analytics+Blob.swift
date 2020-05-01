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
        var params: AnalyticsEnums.Params = ["identifier": identifier, "blob": AnalyticsEnums.Name.publishBlob.rawValue]
        if let numberOfBytes = numberOfBytes { params["number_of_bytes"] = numberOfBytes }
        self.track(event: .did,
                   element: .bot,
                   name: "publish_blob",
                   params: params)
    }

    enum DidLoadBlobError: String {
        case notAvailable = "not_available"
        case emptyData = "empty_data"
        case notImageData = "not_image_data"
    }

    func trackAppDidLoad(_ identifier: BlobIdentifier, error: DidLoadBlobError? = nil) {
        var params: AnalyticsEnums.Params = ["identifier": identifier, "blob": AnalyticsEnums.Name.loadBlob.rawValue]
        if let error = error { params["error"] = error.rawValue }
        self.track(event: .did,
                   element: .app,
                   name: "load_blob",
                   params: params)
    }
    
}
