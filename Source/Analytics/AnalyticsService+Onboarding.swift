//
//  AnalyticsService+Onboarding.swift
//  FBTT
//
//  Created by Christoph on 7/25/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

extension AnalyticsService {

    func trackOnboarding(_ step: OnboardingStep.Name) {

        let params = ["step": step.rawValue]

        self.track(event: .view,
                   element: .screen,
                   name: AnalyticsEnums.Name.onboarding.rawValue,
                   params: params)
    }

    func trackOnboardingComplete(_ data: OnboardingStepData) {

        let params: AnalyticsEnums.Params = ["allowed_backup":      data.allowedBackup,
                                             "allowed_contacts":    data.allowedContacts,
                                             "bio_length":          data.bio?.count ?? 0,
                                             "following_count":     data.following.count,
                                             "image_set":           data.image != nil,
                                             "joined_directory":    data.joinedDirectory,
                                             "public_web_hosting":  data.publicWebHosting,
                                             "name_length":         data.name?.count ?? 0,
                                             "simulated":           data.simulated]

        self.track(event: .view,
                   element: .screen,
                   name: AnalyticsEnums.Name.onboarding.rawValue,
                   params: params)
    }
    
    /// Tracks a time event for `Onboarding.start()`.
    /// Note that this should not be used to track onboarding screens.
    func trackOnboardingStart() {
        self.time(event: .did, element: .app, name: AnalyticsEnums.Name.onboarding.rawValue)
    }

    /// Marks the end of a time event for `Onboarding.start()`
    /// Note that this should not be used to track onboarding screens.
    func trackOnboardingEnd() {
        self.track(event: .did, element: .app, name: AnalyticsEnums.Name.onboarding.rawValue)
    }
}
