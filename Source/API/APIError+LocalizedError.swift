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
            return Text.Error.unexpected.text
        case .encodeError:
            return Text.Error.unexpected.text
        case .invalidIdentity:
            return Text.Error.unexpected.text
        case .invalidPath:
            return Text.Error.unexpected.text
        case .invalidURL:
            return Text.Error.unexpected.text
        case .httpStatusCode:
            return Text.Error.unexpected.text
        case .other(let error):
            return error.localizedDescription
        }
    }
    
}
