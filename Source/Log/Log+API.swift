//
//  API+Log.swift
//  Planetary
//
//  Created by Christoph on 12/9/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

extension LogService {

    static func optional(_ error: APIError?, from response: URLResponse?) {
        guard let error = error else { return }
        guard let response = response else { return }
        let path = response.url?.path ?? "unknown path"
        let detail = "\(path) \(error)"
        Log.unexpected(.apiError, detail)
    }
}
