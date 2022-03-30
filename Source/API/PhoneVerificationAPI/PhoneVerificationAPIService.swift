//
//  PhoneVerificationAPIService.swift
//  Planetary
//
//  Created by Martin Dutra on 5/18/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation

protocol PhoneVerificationAPIService {

    func requestCode(country: String, phone: String, completion: @escaping ((PhoneVerificationResponse?, APIError?) -> Void))
    
    func verifyCode(_ code: String, country: String, phone: String, completion: @escaping ((PhoneVerificationResponse?, APIError?) -> Void))
}
