//
//  PhotoConfirmOnboardingStep.swift
//  FBTT
//
//  Created by Christoph on 7/16/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import Photos
import UIKit
import Logger
import CrashReporting

class PhotoConfirmOnboardingStep: OnboardingStep {

    private let imagePicker = ImagePicker()

    // TODO this is duplicated from AboutView
    private let circleView: UIView = {
        let view = UIView.forAutoLayout()
        view.stroke()
        return view
    }()

    // TODO this is duplicated from AboutView
    private let imageView: UIImageView = {
        let image = UIImage(named: "missing-about-icon")
        let view = UIImageView(image: image)
        view.contentMode = .scaleAspectFill
        return view
    }()

    init() {
        super.init(.photoConfirm)
    }

    override func customizeView() {
        Layout.center(self.circleView, in: self.view, size: CGSize(square: Layout.profileImageOutside))
        Layout.center(self.imageView, in: self.circleView, size: CGSize(square: Layout.profileImageInside))
        
        self.circleView.roundedCorners(radius: Layout.profileImageOutside / 2)
        self.imageView.roundedCorners(radius: Layout.profileImageInside / 2)

        self.view.secondaryButton.setText(.changePhoto)
        self.view.primaryButton.setText(.confirmPhoto)
    }

    override func willStart() {
        self.imageView.image = self.data.image
    }

    override func performSecondaryAction(sender button: UIButton) {
        self.imagePicker.present(from: button) {
            [unowned self] image in
            self.imageView.image = image
            self.data.image = image
            self.imagePicker.dismiss()
            self.view.lookReady()
        }
    }
}
