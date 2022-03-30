//
//  APIError.swift
//  Planetary
//
//  Created by Martin Dutra on 4/2/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation

enum APIError: Error {

    case decodeError
    case encodeError
    case invalidIdentity
    case invalidPath(String)
    case invalidURL
    case httpStatusCode(Int)
    case other(Error)

    static func optional(_ error: Error?) -> APIError? {
        guard let error = error else { return nil }
        return APIError.other(error)
    }
}
