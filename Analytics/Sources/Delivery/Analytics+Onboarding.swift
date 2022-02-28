//
//  Analytics+Onboarding.swift
//  
//
//  Created by Martin Dutra on 11/12/21.
//

import Foundation
import UIKit

public extension Analytics {

    enum OnboardingStep: String {
        case backup
        case benefits
        case birthday
        case bio
        case contacts
        case directory
        case done
        case earlyAccess
        case join
        case name
        case phone
        case phoneVerify
        case photo
        case photoConfirm
        case resume
        case start
    }
    
    class OnboardingStepData {
        var allowedBackup = false
        var allowedContacts = false
        var bio: String? = nil
        var followingCount = 0
        var hasImage = false
        var joinedDirectory = false
        var publicWebHosting = false
        var nameLength = 0
        var phone: String? = nil
        var simulated = false

        public init(allowedBackup: Bool = false, allowedContacts: Bool = false, bio: String? = nil, followingCount: Int = 0, hasImage: Bool = false, joinedDirectory: Bool = false, publicWebHosting: Bool = false, nameLength: Int = 0, phone: String? = nil, simulated: Bool = false) {
            self.allowedBackup = allowedBackup
            self.allowedContacts = allowedContacts
            self.bio = bio
            self.followingCount = followingCount
            self.hasImage = hasImage
            self.joinedDirectory = joinedDirectory
            self.publicWebHosting = publicWebHosting
            self.nameLength = nameLength
            self.phone = phone
            self.simulated = simulated
        }
    }

    func trackOnboarding(_ step: OnboardingStep) {
        let params = ["step": step.rawValue]
        service.track(event: .view, element: .screen, name: "onboarding", params: params)
    }

    func trackOnboardingComplete(_ data: OnboardingStepData) {
        let params = ["allowed_backup":      data.allowedBackup,
                      "allowed_contacts":    data.allowedContacts,
                      "bio_length":          data.bio?.count ?? 0,
                      "following_count":     data.followingCount,
                      "image_set":           data.hasImage,
                      "joined_directory":    data.joinedDirectory,
                      "public_web_hosting":  data.publicWebHosting,
                      "name_length":         data.nameLength,
                      "simulated":           data.simulated] as [String : Any]
        service.track(event: .view, element: .screen, name: "onboarding", params: params)
    }

    /// Tracks a time event for `Onboarding.start()`.
    /// Note that this should not be used to track onboarding screens.
    func trackOnboardingStart() {
        service.track(event: .did, element: .app, name: "onboarding_start")
    }

    /// Marks the end of a time event for `Onboarding.start()`
    /// Note that this should not be used to track onboarding screens.
    func trackOnboardingEnd() {
        service.track(event: .did, element: .app, name: "onboarding_end")
    }

}
