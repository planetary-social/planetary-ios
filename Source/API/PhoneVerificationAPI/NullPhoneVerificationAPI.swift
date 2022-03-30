//
//  NullPhoneVerificationAPI.swift
//  Planetary
//
//  Created by Martin Dutra on 5/18/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation

class NullPhoneVerificationAPI: PhoneVerificationAPIService {

    func requestCode(country: String, phone: String, completion: @escaping ((PhoneVerificationResponse?, APIError?) -> Void)) {
        completion(PhoneVerificationResponse(message: "", success: true, uuid: nil), nil)
    }
    
    func verifyCode(_ code: String, country: String, phone: String, completion: @escaping ((PhoneVerificationResponse?, APIError?) -> Void)) {
        completion(PhoneVerificationResponse(message: "", success: true, uuid: nil), nil)
    }
}
