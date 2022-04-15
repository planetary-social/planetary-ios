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
    let buttonBlock = UIImage(named: "button-block")
    let buttonBlocked = UIImage(named: "button-blocked")
    let buttonFollow = UIImage(named: "button-follow")
    let buttonFollowing = UIImage(named: "button-following")
    let camera = UIImage(named: "nav-icon-camera")
    let cameraLarge = UIImage(named: "camera-large")
    let cellChevron = UIImage(named: "cell-chevron")
    let dismiss = UIImage(named: "nav-icon-dismiss")
    let editPencil = UIImage(named: "button-pencil")
    let help = UIImage(named: "icon-help")
    let like = UIImage(named: "icon-like")
    let liked = UIImage(named: "icon-liked")
    let missingAbout = UIImage(named: "missing-about-icon")
    let newPostOpenLibrary = UIImage(named: "icon-library")
    let onboardingButton = UIImage(named: "onboarding-button")
    let profile = UIImage(named: "icon-profile")
    let reportBug = UIImage(named: "icon-report-bug")
    let settings = UIImage(named: "icon-settings")
    let share = UIImage(named: "icon-share")
    let smallShare = UIImage(named: "button-share")
    let optionsOff = UIImage(named: "icon-options-off")
    let optionsOn = UIImage(named: "icon-options-on")
    let unsupportedBlobPlaceholder = UIImage(named: "unsupported-blob-placeholder", in: Bundle.current, with: nil)!
}

extension UIImage {
    static let verse = VerseImages()
}
