//
//  PhoneVerificationResponse.swift
//  Planetary
//
//  Created by Martin Dutra on 5/18/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation

struct PhoneVerificationResponse: Codable {
    let message: String
    let success: Bool
    let uuid: String?
}
