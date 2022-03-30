//
//  PhoneVerificationAPI.swift
//  Planetary
//
//  Created by Martin Dutra on 5/20/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation

struct PhoneVerificationAPI {
    
    static var shared: PhoneVerificationAPIService = {
        // We don't want to spam the push API when running tests
        #if UNIT_TESTS
        return NullPhoneVerificationAPI()
        #else
        if CommandLine.arguments.contains("mock-phone-verification-api") {
            return NullPhoneVerificationAPI()
        } else {
            return AuthyPhoneVerificationAPI()
        }
        #endif
    }()
}
