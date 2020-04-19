//
//  UIImage+Verse.swift
//  FBTT
//
//  Created by Christoph on 3/30/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

struct VerseImages {
    let bookmark = UIImage(named: "icon-bookmark")
    let buttonBlock = UIImage(named: "button-block")
    let buttonBlocked = UIImage(named: "button-blocked")
    let buttonFollow = UIImage(named: "button-follow")
    let buttonFollowing = UIImage(named: "button-following")
    let camera = UIImage(named: "nav-icon-camera")
    let cameraLarge = UIImage(named: "camera-large")
    let cellChevron = UIImage(named: "cell-chevron")
    let dismiss = UIImage(named: "nav-icon-dismiss")
    let editPencil = UIImage(named: "button-pencil")
    let editProfileOff = UIImage(named: "icon-edit-off")
    let editProfileOn = UIImage(named: "icon-edit-on")
    let help = UIImage(named: "icon-help")
    let like = UIImage(named: "icon-like")
    let link = UIImage(named: "icon-link")
    let missingAbout = UIImage(named: "missing-about-icon")
    let newPostOpenLibrary = UIImage(named: "icon-library")
    let onboardingButton = UIImage(named: "onboarding-button")
    let profile = UIImage(named: "icon-profile")
    let relationship = UIImage(named: "icon-relationship-none")
    let relationshipBlocked = UIImage(named: "icon-relationship-blocked")
    let relationshipFollowing = UIImage(named: "icon-relationship-following")
    let relationshipFriend = UIImage(named: "icon-relationship-friend")
    let reportBug = UIImage(named: "icon-report-bug")
    let settings = UIImage(named: "icon-settings")
    let share = UIImage(named: "icon-share")
    let options = UIImage(named: "icon-options")
}

extension UIImage {
    static let verse = VerseImages()
}
