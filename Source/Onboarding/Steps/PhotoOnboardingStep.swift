//
//  PhotoOnboardingStep.swift
//  FBTT
//
//  Created by Christoph on 7/16/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import Photos
import UIKit

class PhotoOnboardingStep: OnboardingStep, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    private let imagePicker = ImagePicker()

    init() {
        super.init(.photo)
    }

    private let circleView: UIView = {
        let view = UIView.forAutoLayout()
        view.backgroundColor = .appBackground
        view.stroke()
        return view
    }()

    private lazy var cameraButton: UIButton = {
        let view = UIButton(type: .custom)
        view.backgroundColor = .appBackground
        view.setImage(UIImage.verse.cameraLarge, for: .normal)
        view.imageEdgeInsets = UIEdgeInsets(top: -60, left: 0, bottom: 0, right: 0)
        view.addTarget(self, action: #selector(performPrimaryAction), for: .touchUpInside)
        return view
    }()

    let circleLabel: UILabel = {
        let label = UILabel.forAutoLayout()
        label.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        label.numberOfLines = 2
        label.textAlignment = .center
        label.textColor = UIColor.tint.default
        label.text = Text.Onboarding.chooseProfileImage.text
        return label
    }()

    override func customizeView() {
        self.view.secondaryButton.setText(.photoButtonLater)
        self.view.primaryButton.setText(.photoButtonAdd)

        Layout.center(self.circleView, in: self.view, size: CGSize(square: Layout.profileImageOutside))
        Layout.center(self.cameraButton, in: self.circleView, size: CGSize(square: Layout.profileImageInside))

        self.circleView.roundedCorners(radius: Layout.profileImageOutside / 2)
        self.cameraButton.roundedCorners(radius: Layout.profileImageInside / 2)

        self.circleView.addSubview(self.circleLabel)
        Layout.center(self.circleLabel, atTopOf: self.circleView, inset: 94)
    }

    override func performSecondaryAction(sender button: UIButton) {
        self.next(.bio)
    }

    @objc override func performPrimaryAction(sender button: UIButton) {
        self.imagePicker.present(from: button, openCameraInSelfieMode: true) {
            [unowned self] image in
            guard let image = image else { return }
            self.data.image = image
            self.imagePicker.dismiss()
            self.next()
        }
    }
}
