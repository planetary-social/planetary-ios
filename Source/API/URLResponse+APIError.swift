//
//  URLResponse+APIError.swift
//  FBTT
//
//  Created by Christoph on 6/11/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

extension URLResponse {

    var httpStatusCodeError: APIError? {
        guard let response = self as? HTTPURLResponse else { return nil }
        if response.statusCode > 201 { return APIError.httpStatusCode(response.statusCode) } else { return nil }
    }
}
