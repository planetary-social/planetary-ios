//
//  Onboarding+Verify.swift
//  FBTT
//
//  Created by Christoph on 5/29/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

extension Onboarding {

    static func requestCode(country: String,
                            phone: String,
                            completion: @escaping OnboardingCompletion) {
        assert(Thread.isMainThread)
        guard !country.isEmpty else { completion(false, .invalidCountryCode); return }
        guard !phone.isEmpty else { completion(false, .invalidPhoneNumber); return }

        PhoneVerificationAPI.shared.requestCode(country: country, phone: phone) {
            response, error in
            completion(response?.success ?? false, OnboardingError.optional(error))
        }
    }

    static func verifyCode(_ code: String,
                           country: String,
                           phone: String,
                           completion: @escaping OnboardingCompletion) {
        assert(Thread.isMainThread)
        guard !code.isEmpty else { completion(false, .invalidVerificationCode); return }
        guard !country.isEmpty else { completion(false, .invalidCountryCode); return }
        guard !phone.isEmpty else { completion(false, .invalidPhoneNumber); return }

        PhoneVerificationAPI.shared.verifyCode(code, country: country, phone: phone) {
            response, error in
            completion(response?.success ?? false, OnboardingError.optional(error))
        }
    }
}
