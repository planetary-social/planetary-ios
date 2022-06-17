//
//  APIError+LocalizedError.swift
//  Planetary
//
//  Created by Martin Dutra on 4/2/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation

extension APIError: LocalizedError {
    
    var errorDescription: String? {
        switch self {
        case .decodeError:
            return "Decode error"
        case .encodeError:
            return "Encode error"
        case .invalidIdentity:
            return "Invalid identity"
        case .invalidPath:
            return "Invalid path"
        case .invalidURL:
            return "Invalid URL"
        case .invalidBody:
            return "Invalid reponse body"
        case .httpStatusCode(let statusCode):
            return "Status code: \(statusCode)"
        case .other(let error):
            return error.localizedDescription
        }
    }
}
