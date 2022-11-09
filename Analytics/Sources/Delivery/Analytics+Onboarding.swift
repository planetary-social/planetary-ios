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
        case rooms
        case alias

        /// Used for safeguarding. Each onboarding step should be identified accordingly
        case unknown
    }

    class OnboardingStepData {
        var allowedBackup = false
        var allowedContacts = false
        var bio: String?
        var followingCount = 0
        var hasImage = false
        var joinedDirectory = false
        var joinPlanetarySystem = false
        var useTestNetwork = false
        var publicWebHosting = false
        var analytics = false
        var followPlanetary = false
        var nameLength = 0
        var phone: String?
        var simulated = false

        public init(
            allowedBackup: Bool = false,
            allowedContacts: Bool = false,
            bio: String? = nil,
            followingCount: Int = 0,
            hasImage: Bool = false,
            joinedDirectory: Bool = false,
            joinPlanetarySystem: Bool = false,
            useTestNetwork: Bool = false,
            publicWebHosting: Bool = false,
            analytics: Bool = false,
            followPlanetary: Bool = false,
            nameLength: Int = 0,
            phone: String? = nil,
            simulated: Bool = false
        ) {
            self.allowedBackup = allowedBackup
            self.allowedContacts = allowedContacts
            self.bio = bio
            self.followingCount = followingCount
            self.hasImage = hasImage
            self.joinedDirectory = joinedDirectory
            self.joinPlanetarySystem = joinPlanetarySystem
            self.useTestNetwork = useTestNetwork
            self.publicWebHosting = publicWebHosting
            self.analytics = analytics
            self.followPlanetary = followPlanetary
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
        let params: [String: Any] = [
            "allowed_backup": data.allowedBackup,
            "allowed_contacts": data.allowedContacts,
            "bio_length": data.bio?.count ?? 0,
            "following_count": data.followingCount,
            "image_set": data.hasImage,
            "joined_directory": data.joinedDirectory,
            "join_planetary_system": data.joinPlanetarySystem,
            "use_test_network": data.useTestNetwork,
            "public_web_hosting": data.publicWebHosting,
            "analytics": data.analytics,
            "followPlanetary": data.followPlanetary,
            "name_length": data.nameLength,
            "simulated": data.simulated
        ]
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
