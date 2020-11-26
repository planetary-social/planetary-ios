//
//  AppError.swift
//  Planetary
//
//  Created by Martin Dutra on 4/2/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation

/// An error in caused by code in the App's domain
/// Not GoBot or something else
enum AppError: Error {
    case unexpected
    case invalidInvite
}
