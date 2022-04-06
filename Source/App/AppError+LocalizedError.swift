//
//  AppError+LocalizedError.swift
//  Planetary
//
//  Created by Martin Dutra on 4/2/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation

extension AppError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .unexpected:
            return Text.Error.unexpected.text
        case .invalidInvite:
            return Text.Error.unexpected.text
        }
    }
}
